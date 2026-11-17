// Prueba de carga de la ruta crítica (redirección). Uso:
//   k6 run -e BASE=https://kut.nz -e CODES=abc1234,expo-desi loadtest/redirect.js
// Sube hasta 400 req/s (pico estimado), lo sostiene y verifica el SLO: p95 < 50 ms en el servidor
// (Server-Timing) y menos de 0.1 % de errores.
import http from "k6/http";
import { check } from "k6";
import { Trend } from "k6/metrics";

const BASE = __ENV.BASE || "https://kut.nz";
const CODES = (__ENV.CODES || "").split(",").filter(Boolean);
const serverTime = new Trend("server_time_ms", true);

export const options = {
  scenarios: {
    pico: {
      executor: "ramping-arrival-rate",
      startRate: 20, timeUnit: "1s", preAllocatedVUs: 200, maxVUs: 1000,
      stages: [
        { target: 100, duration: "1m" },
        { target: 400, duration: "2m" },
        { target: 400, duration: "5m" },
        { target: 0, duration: "1m" },
      ],
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.001"],
    server_time_ms: ["p(95)<50"],
    http_req_duration: ["p(95)<300"], // incluye la red desde donde corre k6
  },
};

export default function () {
  const code = CODES[Math.floor(Math.random() * CODES.length)];
  const res = http.get(`${BASE}/${code}`, {
    redirects: 0,
    headers: { "User-Agent": "Mozilla/5.0 (k6 load test) Chrome/130" },
    tags: { name: "redirect" },
  });
  check(res, { "302": (r) => r.status === 302, "sin caché del navegador": (r) => /no-store/.test(r.headers["Cache-Control"] || "") });
  const m = /app;dur=([\d.]+)/.exec(res.headers["Server-Timing"] || "");
  if (m) serverTime.add(Number(m[1]));
}
