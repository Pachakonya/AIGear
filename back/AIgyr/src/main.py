from fastapi import FastAPI, Body
from src.posts.router import router as post_router
from src.database import Base, engine
from fastapi.responses import JSONResponse

from celery_app import create_task

Base.metadata.create_all(bind=engine)

app = FastAPI()

@app.post('/ex1')
def run_tasks(data=Body(...)):
    amount = int(data['amount'])
    x = data['x']
    y = data['y']
    task = create_task.delay(amount, x, y)
    return JSONResponse(content={'task_id': task.id})

app.include_router(post_router)
