from fastapi import FastAPI
import random

app = FastAPI()


items = {}

@app.get("/")
def read_root():
    return {"Hello": "World"}


@app.get("/items/{item_id}")
def read_item(item_id: str, token: str):
    try:
        return {"item": items[item_id][token]}
    except KeyError:
        return {"item": ""}

@app.post("/items/{item_id}/{item}")
def create_item(item_id: str, item: str, token: str = str(random.randint(10000000, 99999999))):
    if item_id in items:
        return {"already": "exists"}
    items[item_id] = {token: item}
    return {"item": item, "token": token}


