// Demostración de exactitud bajo concurrencia: 1 000 visitas simultáneas a un enlace con máximo 100.
//   k6 run -e BASE=https://kut.nz -e CODE=<código con max_clicks=100> loadtest/click_limit.js
// Resultado esperado: exactamente 100 respuestas 302 y 900 respuestas 410.
import http from "k6/http";
import { Counter } from "k6/metrics";

const ok = new Counter("redirecciones_302");
const gone = new Counter("agotado_410");

export const options = {
  scenarios: { rafaga: { executor: "shared-iterations", vus: 200, iterations: 1000, maxDuration: "1m" } },
};

export default function () {
  const r = http.get(`${__ENV.BASE}/${__ENV.CODE}`, {
    redirects: 0, headers: { "User-Agent": "Mozilla/5.0 (k6 concurrency test) Chrome/130" },
  });
  if (r.status === 302) ok.add(1);
  else if (r.status === 410) gone.add(1);
}
