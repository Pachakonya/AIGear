import os
from dotenv import load_dotenv
import psycopg2

load_dotenv() 

DATABASE_URL = os.getenv("DATABASE_URL")
print("DATABASE_URL:", DATABASE_URL) 

try:
    # Connect to your postgres DB
    conn = psycopg2.connect(DATABASE_URL)
    print("Connection successful!")

    # Create a cursor object
    cur = conn.cursor()
    cur.execute("SELECT version();")
    db_version = cur.fetchone()
    print("Database version:", db_version)

    # Close the connection
    cur.close()
    conn.close()
except Exception as e:
    print("Connection failed!")
    print(e)