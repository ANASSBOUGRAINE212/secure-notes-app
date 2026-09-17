from conftest import make_token


def test_notes_requires_auth(client):
    res = client.get("/notes")
    assert res.status_code == 401


def test_create_and_list_note(client, auth_headers):
    create = client.post("/notes", json={
        "title": "First note",
        "content": "hello world",
    }, headers=auth_headers)
    assert create.status_code == 201
    body = create.json()
    assert body["title"] == "First note"
    assert body["content"] == "hello world"

    listing = client.get("/notes", headers=auth_headers)
    assert listing.status_code == 200
    assert len(listing.json()) == 1


def test_update_note(client, auth_headers):
    create = client.post("/notes", json={
        "title": "Original",
        "content": "before edit",
    }, headers=auth_headers)
    note_id = create.json()["id"]

    update = client.put(f"/notes/{note_id}", json={
        "title": "Updated",
        "content": "after edit",
    }, headers=auth_headers)
    assert update.status_code == 200
    assert update.json()["title"] == "Updated"
    assert update.json()["content"] == "after edit"


def test_delete_note(client, auth_headers):
    create = client.post("/notes", json={
        "title": "To delete",
        "content": "bye",
    }, headers=auth_headers)
    note_id = create.json()["id"]

    delete = client.delete(f"/notes/{note_id}", headers=auth_headers)
    assert delete.status_code == 204

    fetch = client.get(f"/notes/{note_id}", headers=auth_headers)
    assert fetch.status_code == 404


def test_cannot_access_another_users_note(client, auth_headers):
    # user 1 creates a note
    create = client.post("/notes", json={
        "title": "User 1's note",
        "content": "private",
    }, headers=auth_headers)
    note_id = create.json()["id"]

    # user 2 tries to fetch it
    user_2_headers = {"Authorization": f"Bearer {make_token(user_id=2)}"}
    res = client.get(f"/notes/{note_id}", headers=user_2_headers)
    assert res.status_code == 404  # not 403 - we don't reveal it exists


def test_invalid_token_rejected(client):
    res = client.get("/notes", headers={"Authorization": "Bearer not-a-real-token"})
    assert res.status_code == 401