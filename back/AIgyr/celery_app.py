# import os 
# import time
# from celery import Celery
# from dotenv import load_dotenv

# load_dotenv()

# app = Celery(
#     "tasks",
#     broker=os.getenv("CELERY_BROKER_URL"),
#     backend=os.getenv("CELERY_RESULT_BACKEND"),
# )

# @app.task(name = "create_task")
# def create_task(a, b, c):
#     time.sleep(a)
#     return b + c