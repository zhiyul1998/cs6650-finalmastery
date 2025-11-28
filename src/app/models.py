from pydantic import BaseModel, Field, validator
from typing import Optional

class Product(BaseModel):
    id: int = Field(..., ge=1, description="Must match the URI productId")
    name: str = Field(..., min_length=1)
    price: float = Field(..., ge=0)
    description: Optional[str] = None

class Error(BaseModel):
    code: str
    message: str

    @validator("code")
    def non_empty(cls, v):
        if not v:
            raise ValueError("code must be non-empty")
        return v
