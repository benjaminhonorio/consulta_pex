import * as readline from "node:readline";
import { firefox } from "playwright";

const LOGIN_URL =
  "https://api-seguridad.sunat.gob.pe/v1/clientessol/085b176d-2437-44cd-8c3e-e9a83b705921/oauth2/loginMenuSol?lang=es-PE&showDni=true&showLanguages=false&originalUrl=https://e-menu.sunat.gob.pe/cl-ti-itmenucabina/AutenticaMenuInternet.htm&state=rO0ABXNyABFqYXZhLnV0aWwuSGFzaE1hcAUH2sHDFmDRAwACRgAKbG9hZEZhY3RvckkACXRocmVzaG9sZHhwP0AAAAAAAAx3CAAAABAAAAADdAAEZXhlY3B0AAZwYXJhbXN0AFEqJiomL2NsLXRpLWl0bWVudWNhYmluYS9NZW51SW50ZXJuZXQuaHRtJjBlMWY4NDg5ZmVlYWJmOTMxNmI5ODUwNTYyMjA5MTE4ZjkxZTJjMmN0AANleGVweA==";

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false,
});

rl.on("line", async (line) => {
  try {
    const { action, credentials } = JSON.parse(line);

    if (action === "login") {
      const cookies = await doLogin(credentials);
      console.log(JSON.stringify({ ok: true, cookies }));
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.log(JSON.stringify({ ok: false, error: message }));
  }
});

async function doLogin({
  ruc,
  usuario_sol,
  clave_sol,
}: {
  ruc: string;
  usuario_sol: string;
  clave_sol: string;
}) {
  const browser = await firefox.launch({ headless: true });

  try {
    const context = await browser.newContext();
    const page = await context.newPage();

    await page.goto(LOGIN_URL);
    await page.waitForTimeout(2000);
    // Ingresar credenciales
    await page.getByRole("textbox", { name: "RUC" }).fill(ruc);
    await page.getByRole("textbox", { name: "Usuario" }).fill(usuario_sol);
    await page.getByRole("textbox", { name: "Contraseña" }).fill(clave_sol);
    await page.getByRole("button", { name: "Iniciar sesión" }).click();

    // Esperar menú
    await page.waitForSelector("text=Empresas", { timeout: 120000 });

    // Navegar a boleta para obtener cookies correctas
    await page.waitForSelector("#divOpcionServicio2", {
      state: "visible",
      timeout: 30000,
    });
    await page.waitForTimeout(1000);
    await page.click("#divOpcionServicio2");
    await page.waitForTimeout(2000);
    await page.click("text=Comprobantes de pago");
    await page.waitForTimeout(1000);
    await page.click("text=SEE - SOL");
    await page.waitForTimeout(1000);
    await page.click("text=Boleta de Venta Electrónica");
    await page.waitForTimeout(1000);
    await page.click("text=Emitir Boleta de Venta >> nth=0");
    await page.waitForTimeout(2000);
    await page.waitForSelector('iframe[name="iframeApplication"]', {
      timeout: 15000,
    });

    // Extraer cookies
    const cookies = await context.cookies(["https://ww1.sunat.gob.pe"]);
    return cookies.map((c) => `${c.name}=${c.value}`).join("; ");
  } finally {
    await browser.close();
  }
}

process.stdin.resume();
