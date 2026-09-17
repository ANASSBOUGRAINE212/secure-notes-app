// two separate backends now - no gateway in this manual/no-Docker setup.
// auth-service handles login/register, notes-service handles everything else.
// MANUAL mode (uncomment this pair, comment out Docker pair)
// const AUTH_BASE = "http://localhost:8001";
// const NOTES_BASE = "http://localhost:8002";

// DOCKER mode (uncomment this pair, comment out Manual pair)
const AUTH_BASE = "http://localhost:8080";
const NOTES_BASE = "http://localhost:8080";

let mode = "login"; // or "register"
let token = localStorage.getItem("notes_token");
let editingNoteId = null;

const authScreen = document.getElementById("authScreen");
const appScreen = document.getElementById("appScreen");
const authForm = document.getElementById("authForm");
const authError = document.getElementById("authError");
const authSubmit = document.getElementById("authSubmit");
const tabLogin = document.getElementById("tabLogin");
const tabRegister = document.getElementById("tabRegister");

const notesList = document.getElementById("notesList");
const emptyState = document.getElementById("emptyState");
const noteTitle = document.getElementById("noteTitle");
const noteContent = document.getElementById("noteContent");
const saveNoteBtn = document.getElementById("saveNoteBtn");
const cancelEditBtn = document.getElementById("cancelEditBtn");
const userEmailEl = document.getElementById("userEmail");
const logoutBtn = document.getElementById("logoutBtn");

init();

function init() {
  tabLogin.addEventListener("click", () => switchTab("login"));
  tabRegister.addEventListener("click", () => switchTab("register"));
  authForm.addEventListener("submit", handleAuthSubmit);
  saveNoteBtn.addEventListener("click", handleSaveNote);
  cancelEditBtn.addEventListener("click", resetComposer);
  logoutBtn.addEventListener("click", logout);

  if (token) {
    showApp();
  } else {
    showAuth();
  }
}

function switchTab(next) {
  mode = next;
  tabLogin.classList.toggle("active", mode === "login");
  tabRegister.classList.toggle("active", mode === "register");
  authSubmit.textContent = mode === "login" ? "log in" : "create account";
  hideAuthError();
}

async function handleAuthSubmit(e) {
  e.preventDefault();
  hideAuthError();

  const email = document.getElementById("email").value.trim();
  const password = document.getElementById("password").value;

  try {
    if (mode === "register") {
      const res = await fetch(`${AUTH_BASE}/auth/register`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      if (!res.ok) throw await extractError(res);
      // registered fine, now just log them straight in
    }

    const form = new URLSearchParams();
    form.append("username", email);
    form.append("password", password);

    const loginRes = await fetch(`${AUTH_BASE}/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
    });
    if (!loginRes.ok) throw await extractError(loginRes);

    const data = await loginRes.json();
    token = data.access_token;
    localStorage.setItem("notes_token", token);
    showApp();
  } catch (err) {
    showAuthError(err.message || "something went wrong, try again");
  }
}

async function extractError(res) {
  try {
    const body = await res.json();
    return new Error(body.detail || "request failed");
  } catch {
    return new Error("request failed");
  }
}

function showAuthError(msg) {
  authError.textContent = msg;
  authError.classList.remove("hidden");
}

function hideAuthError() {
  authError.classList.add("hidden");
}

function showAuth() {
  authScreen.classList.remove("hidden");
  appScreen.classList.add("hidden");
}

async function showApp() {
  authScreen.classList.add("hidden");
  appScreen.classList.remove("hidden");

  try {
    const me = await apiGet(AUTH_BASE, "/auth/me");
    userEmailEl.textContent = me.email;
    await loadNotes();
  } catch {
    // token's dead or expired, kick back to login
    logout();
  }
}

function logout() {
  token = null;
  localStorage.removeItem("notes_token");
  showAuth();
}

async function loadNotes() {
  const notes = await apiGet(NOTES_BASE, "/notes");
  renderNotes(notes);
}

function renderNotes(notes) {
  notesList.innerHTML = "";
  emptyState.classList.toggle("hidden", notes.length > 0);

  for (const note of notes) {
    const el = document.createElement("div");
    el.className = "note";
    el.innerHTML = `
      <h3></h3>
      <p></p>
      <div class="note-meta">
        <span></span>
        <span class="note-actions">
          <button class="ghost edit-btn">edit</button>
          <button class="ghost delete-btn">delete</button>
        </span>
      </div>
    `;
    el.querySelector("h3").textContent = note.title;
    el.querySelector("p").textContent = note.content;
    el.querySelector(".note-meta span").textContent = formatDate(note.created_at);

    el.querySelector(".edit-btn").addEventListener("click", () => startEdit(note));
    el.querySelector(".delete-btn").addEventListener("click", () => deleteNote(note.id));

    notesList.appendChild(el);
  }
}

function formatDate(iso) {
  const d = new Date(iso);
  return d.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
}

function startEdit(note) {
  editingNoteId = note.id;
  noteTitle.value = note.title;
  noteContent.value = note.content;
  saveNoteBtn.textContent = "update note";
  cancelEditBtn.classList.remove("hidden");
  noteTitle.focus();
}

function resetComposer() {
  editingNoteId = null;
  noteTitle.value = "";
  noteContent.value = "";
  saveNoteBtn.textContent = "save note";
  cancelEditBtn.classList.add("hidden");
}

async function handleSaveNote() {
  const title = noteTitle.value.trim();
  const content = noteContent.value.trim();
  if (!title || !content) return;

  if (editingNoteId) {
    await apiRequest(NOTES_BASE, `/notes/${editingNoteId}`, "PUT", { title, content });
  } else {
    await apiRequest(NOTES_BASE, "/notes", "POST", { title, content });
  }

  resetComposer();
  await loadNotes();
}

async function deleteNote(id) {
  if (!confirm("delete this note?")) return;
  await apiRequest(NOTES_BASE, `/notes/${id}`, "DELETE");
  await loadNotes();
}

// ---- tiny fetch wrappers ----

async function apiGet(base, path) {
  return apiRequest(base, path, "GET");
}

async function apiRequest(base, path, method = "GET", body = null) {
  const opts = {
    method,
    headers: { Authorization: `Bearer ${token}` },
  };
  if (body) {
    opts.headers["Content-Type"] = "application/json";
    opts.body = JSON.stringify(body);
  }

  const res = await fetch(`${base}${path}`, opts);
  if (res.status === 401) {
    logout();
    throw new Error("session expired");
  }
  if (!res.ok) throw await extractError(res);
  if (res.status === 204) return null;
  return res.json();
}