def test_register_new_user(client):
    res = client.post("/auth/register", json={
        "email": "alice@example.com",
        "password": "supersecret123",
    })
    assert res.status_code == 201
    body = res.json()
    assert body["email"] == "alice@example.com"
    assert "id" in body
    # password should never come back in the response
    assert "password" not in body
    assert "hashed_password" not in body


def test_register_duplicate_email_rejected(client):
    payload = {"email": "bob@example.com", "password": "supersecret123"}
    first = client.post("/auth/register", json=payload)
    assert first.status_code == 201

    second = client.post("/auth/register", json=payload)
    assert second.status_code == 400


def test_register_short_password_rejected(client):
    res = client.post("/auth/register", json={
        "email": "carol@example.com",
        "password": "short",  # under the 8-char minimum
    })
    assert res.status_code == 422


def test_login_with_correct_credentials(client):
    client.post("/auth/register", json={
        "email": "dave@example.com",
        "password": "supersecret123",
    })

    res = client.post("/auth/login", data={
        "username": "dave@example.com",
        "password": "supersecret123",
    })
    assert res.status_code == 200
    body = res.json()
    assert "access_token" in body
    assert body["token_type"] == "bearer"


def test_login_with_wrong_password_rejected(client):
    client.post("/auth/register", json={
        "email": "eve@example.com",
        "password": "supersecret123",
    })

    res = client.post("/auth/login", data={
        "username": "eve@example.com",
        "password": "wrongpassword",
    })
    assert res.status_code == 401


def test_login_with_unknown_email_rejected(client):
    res = client.post("/auth/login", data={
        "username": "nobody@example.com",
        "password": "whatever123",
    })
    assert res.status_code == 401


def test_me_requires_valid_token(client):
    # no Authorization header at all
    res = client.get("/auth/me")
    assert res.status_code == 401


def test_me_returns_current_user(client):
    client.post("/auth/register", json={
        "email": "frank@example.com",
        "password": "supersecret123",
    })
    login = client.post("/auth/login", data={
        "username": "frank@example.com",
        "password": "supersecret123",
    })
    token = login.json()["access_token"]

    res = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    assert res.json()["email"] == "frank@example.com"