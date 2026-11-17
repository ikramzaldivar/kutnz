// Carga constante para las pruebas de caos: correr y, mientras tanto, ejecutar scripts/chaos.sh az|redis.
//   k6 run -e BASE=https://kut.nz -e CODES=a,b,c --out csv=caos.csv loadtest/caos.js
import http from "k6/http";
import { check } from "k6";
const CODES = (__ENV.CODES || "").split(",").filter(Boolean);
export const options = {
  scenarios: { constante: { executor: "constant-arrival-rate", rate: 150, timeUnit: "1s", duration: __ENV.DUR || "10m", preAllocatedVUs: 100, maxVUs: 500 } },
};
export default function () {
  const r = http.get(`${__ENV.BASE}/${CODES[Math.floor(Math.random() * CODES.length)]}`,
    { redirects: 0, headers: { "User-Agent": "Mozilla/5.0 (k6 chaos test) Chrome/130" } });
  check(r, { "302": (x) => x.status === 302 });
}
