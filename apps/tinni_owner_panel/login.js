const form = document.getElementById("loginForm");
const button = document.getElementById("loginButton");
const statusEl = document.getElementById("status");
const password = document.getElementById("password");
const toggle = document.getElementById("togglePassword");

toggle.addEventListener("click", () => {
  const showing = password.type === "text";
  password.type = showing ? "password" : "text";
  toggle.textContent = showing ? "Show" : "Hide";
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  statusEl.textContent = "";
  button.disabled = true;
  button.textContent = "Signing in…";

  try {
    const response = await fetch("/auth/login", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        email: document.getElementById("email").value.trim(),
        password: password.value,
      }),
    });

    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(data.error || "Login failed");
    }

    window.location.replace("/");
  } catch (error) {
    statusEl.textContent = error.message || "Login failed";
  } finally {
    button.disabled = false;
    button.textContent = "Login";
  }
});
