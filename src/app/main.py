from fastapi import FastAPI, Path, HTTPException, Request
from fastapi.responses import JSONResponse
from app.models import Product, Error
from typing import Dict

# In-memory "database"
store: Dict[int, Product] = {
    1: Product(id=1, name="Cotton T-Shirt", price=12.99, description="Classic crew neck short sleeve t-shirt"),
    2: Product(id=2, name="Running Shoes", price=54.99, description="Lightweight breathable sneakers for everyday wear"),
    3: Product(id=3, name="Reusable Water Bottle", price=19.99, description="32oz insulated stainless steel water bottle"),
    4: Product(id=4, name="Yoga Mat", price=24.99, description="Non-slip exercise mat, 1/4 inch thick"),
    5: Product(id=5, name="Backpack", price=39.99, description="Durable everyday backpack with laptop compartment"),
    6: Product(id=6, name="Throw Blanket", price=29.99, description="Soft fleece throw blanket, 50x60 inches"),
    7: Product(id=7, name="Coffee Mug", price=9.99, description="Ceramic coffee mug, 12oz"),
    8: Product(id=8, name="Notebook Set", price=14.99, description="Pack of 3 lined notebooks, A5 size"),
    9: Product(id=9, name="Scented Candle", price=16.99, description="Soy wax candle, lavender scent, 40-hour burn"),
    10: Product(id=10, name="Pillow", price=22.99, description="Standard size hypoallergenic bed pillow"),
}

app = FastAPI(
    title="E-commerce API",
    description="API for managing products, shopping carts, warehouse operations, and credit card processing",
    version="1.0.0",
    openapi_tags=[{"name": "Products"}]
)

# ---------- Error shaping ----------

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    code = (
        "NOT_FOUND" if exc.status_code == 404 else
        "BAD_REQUEST" if exc.status_code == 400 else
        "INTERNAL_SERVER_ERROR" if exc.status_code >= 500 else
        "ERROR"
    )
    return JSONResponse(
        status_code=exc.status_code,
        content=Error(code=code, message=str(exc.detail)).dict(),
    )

@app.middleware("http")
async def catch_all_exceptions(request: Request, call_next):
    try:
        return await call_next(request)
    except HTTPException:
        raise
    except Exception:
        return JSONResponse(
            status_code=500,
            content=Error(code="INTERNAL_SERVER_ERROR", message="An unexpected error occurred").dict(),
        )

# -------------- Endpoints --------------

@app.get("/v1/products/{productId}", response_model=Product, tags=["Products"], summary="Get product by ID")
async def get_product(
    productId: int = Path(..., ge=1, description="Unique identifier for the product"),
):
    product = store.get(productId)
    if not product:
        raise HTTPException(status_code=404, detail=f"Product {productId} not found")
    return product


@app.post("/v1/products/{productId}/details", tags=["Products"], summary="Add product details", status_code=204)
async def add_product_details(
    productId: int = Path(..., ge=1, description="Unique identifier for the product"),
    body: Product = ...,
):
    if body.id != productId:
        raise HTTPException(status_code=400, detail="Invalid input data: Body id must match path productId")

    current = store.get(productId)
    if not current:
        raise HTTPException(status_code=404, detail=f"Product {productId} not found")

    updated = current.copy(update=body.dict(exclude_unset=True))
    store[productId] = updated