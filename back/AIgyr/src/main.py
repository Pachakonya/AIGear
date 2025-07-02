from fastapi import FastAPI, Body
from src.posts.router import router as post_router
from src.database import Base, engine
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from src.aiengine.router import router as aiengine_router
from src.auth.router import router as auth_router

from celery_app import create_task

Base.metadata.create_all(bind=engine)

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For testing, use wildcard. Later, restrict to iOS domain.
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post('/ex1')
def run_tasks(data=Body(...)):
    amount = int(data['amount'])
    x = data['x']
    y = data['y']
    task = create_task.delay(amount, x, y)
    return JSONResponse(content={'task_id': task.id})

app.include_router(post_router)
app.include_router(aiengine_router)
app.include_router(auth_router)
