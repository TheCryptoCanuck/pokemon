from fastapi import APIRouter

from app.api.v1.endpoints import auth, birds, collection

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(birds.router)
api_router.include_router(collection.router)
