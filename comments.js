import { initializeApp } from "https://www.gstatic.com/firebasejs/13.1.0/firebase-app.js";
import { getAuth, signInAnonymously } from "https://www.gstatic.com/firebasejs/13.1.0/firebase-auth.js";
import { getFirestore, collection, addDoc, getDocs, query, where, orderBy, limit, serverTimestamp } from "https://www.gstatic.com/firebasejs/13.1.0/firebase-firestore.js";
import { firebaseConfig, appCheckSiteKey } from "./firebase-config.js";

const form = document.querySelector("#comment-form");
const nameInput = document.querySelector("#comment-name");
const textInput = document.querySelector("#comment-text");
const submitButton = document.querySelector("#comment-submit");
const statusBox = document.querySelector("#comment-status");
const list = document.querySelector("#comment-list");
const count = document.querySelector("#comment-count");
const suggestionForm = document.querySelector("#suggestion-form");
const suggestionName = document.querySelector("#suggestion-name");
const suggestionText = document.querySelector("#suggestion-text");
const suggestionButton = document.querySelector("#suggestion-submit");
const suggestionStatus = document.querySelector("#suggestion-status");
const suggestionCount = document.querySelector("#suggestion-count");

function configured() {
  return firebaseConfig.apiKey && firebaseConfig.projectId && firebaseConfig.appId &&
    !Object.values(firebaseConfig).some(value => typeof value === "string" && /^(REEMPLAZAR_|REPLACE_)/.test(value));
}
function setStatus(element, message, kind = "") {
  element.textContent = message;
  element.dataset.kind = kind;
}
function showComments(items) {
  list.replaceChildren();
  if (!items.length) {
    const li = document.createElement("li");
    li.className = "comment-empty";
    li.textContent = "Todavía no hay comentarios publicados. ¡Sé el primero!";
    list.append(li);
    return;
  }
  for (const item of items) {
    const li = document.createElement("li");
    li.className = "comment-item";
    const meta = document.createElement("div");
    meta.className = "comment-meta";
    const author = document.createElement("span");
    author.textContent = item.name || "Visitante";
    meta.append(author);
    const date = document.createElement("time");
    if (item.createdAt?.toDate) {
      const created = item.createdAt.toDate();
      date.dateTime = created.toISOString();
      date.textContent = new Intl.DateTimeFormat("es", { dateStyle: "medium" }).format(created);
    }
    meta.append(date);
    const message = document.createElement("p");
    message.className = "comment-message";
    message.textContent = item.text || "";
    li.append(meta, message);
    list.append(li);
  }
}

textInput.addEventListener("input", () => count.textContent = String(textInput.value.length));
suggestionText.addEventListener("input", () => suggestionCount.textContent = String(suggestionText.value.length));

form.addEventListener("submit", async event => {
  event.preventDefault();
  if (!window.commentsFirebase) return;
  const text = textInput.value.trim();
  const name = nameInput.value.trim() || "Visitante";
  if (!text || text.length > 500 || name.length > 40) {
    setStatus(statusBox, "Revisa el comentario y el límite de caracteres.", "error");
    return;
  }
  submitButton.disabled = true;
  setStatus(statusBox, "Enviando comentario…");
  try {
    await addDoc(collection(window.commentsFirebase.db, "comments"), {
      name, text, status: "pending", authorId: window.commentsFirebase.user.uid, createdAt: serverTimestamp()
    });
    form.reset();
    count.textContent = "0";
    setStatus(statusBox, "Recibimos tu comentario. Aparecerá cuando sea aprobado.", "success");
  } catch (error) {
    console.error("No se pudo guardar el comentario", error);
    setStatus(statusBox, "No pudimos enviar tu comentario. Inténtalo de nuevo más tarde.", "error");
  } finally {
    submitButton.disabled = false;
  }
});

suggestionForm.addEventListener("submit", async event => {
  event.preventDefault();
  if (!window.commentsFirebase) return;
  const suggestion = suggestionText.value.trim();
  const name = suggestionName.value.trim() || "Visitante";
  if (suggestion.length < 5 || suggestion.length > 500 || name.length > 40) {
    setStatus(suggestionStatus, "Escribe una sugerencia de 5 a 500 caracteres.", "error");
    return;
  }
  suggestionButton.disabled = true;
  setStatus(suggestionStatus, "Enviando sugerencia…");
  try {
    await addDoc(collection(window.commentsFirebase.db, "guideSuggestions"), {
      name, suggestion, status: "pending", authorId: window.commentsFirebase.user.uid, createdAt: serverTimestamp()
    });
    suggestionForm.reset();
    suggestionCount.textContent = "0";
    setStatus(suggestionStatus, "¡Gracias! Recibimos tu propuesta para futuras guías.", "success");
  } catch (error) {
    console.error("No se pudo guardar la sugerencia", error);
    setStatus(suggestionStatus, "No pudimos enviar la sugerencia. Inténtalo de nuevo más tarde.", "error");
  } finally {
    suggestionButton.disabled = false;
  }
});

async function start() {
  if (!configured()) {
    list.innerHTML = "<li class=\"comment-empty\">Este espacio se activará cuando se complete la conexión de comentarios.</li>";
    setStatus(statusBox, "Falta conectar el proyecto de comentarios.");
    setStatus(suggestionStatus, "Falta conectar el proyecto de comentarios.");
    return;
  }
  try {
    const app = initializeApp(firebaseConfig);
    if (appCheckSiteKey) {
      const { initializeAppCheck, ReCaptchaV3Provider } = await import("https://www.gstatic.com/firebasejs/13.1.0/firebase-app-check.js");
      initializeAppCheck(app, { provider: new ReCaptchaV3Provider(appCheckSiteKey), isTokenAutoRefreshEnabled: true });
    }
    const auth = getAuth(app);
    const credential = await signInAnonymously(auth);
    const db = getFirestore(app);
    window.commentsFirebase = { db, user: credential.user };
    submitButton.disabled = false;
    suggestionButton.disabled = false;
    const commentsQuery = query(collection(db, "comments"), where("status", "==", "approved"), orderBy("createdAt", "desc"), limit(50));
    const snapshot = await getDocs(commentsQuery);
    showComments(snapshot.docs.map(doc => doc.data()));
    setStatus(statusBox, "Puedes comentar sin crear una cuenta. Los mensajes nuevos se revisan antes de publicarse.");
    setStatus(suggestionStatus, "Puedes enviar una propuesta sin crear una cuenta. La revisaremos antes de usarla.");
  } catch (error) {
    console.error("Error al iniciar comentarios y sugerencias", error);
    setStatus(statusBox, "No pudimos conectar los comentarios. El administrador debe revisar la configuración.", "error");
    setStatus(suggestionStatus, "No pudimos conectar las sugerencias. El administrador debe revisar la configuración.", "error");
    list.innerHTML = "<li class=\"comment-empty\">Los comentarios no están disponibles por el momento.</li>";
  }
}
start();
