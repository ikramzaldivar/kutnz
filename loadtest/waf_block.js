// Evidencia del rate limit del WAF: una sola IP a 40 req/s (límite: 2 000 peticiones por IP en 5 min).
//   k6 run -e BASE=https://kut.nz -e CODES=a,b,c --out csv=waf.csv loadtest/waf_block.js
import http from "k6/http";
const CODES = (__ENV.CODES || "").split(",").filter(Boolean);
export const options = {
  scenarios: { rafaga: { executor: "constant-arrival-rate", rate: 40, timeUnit: "1s", duration: "2m", preAllocatedVUs: 50, maxVUs: 200 } },
};
export default function () {
  http.get(`${__ENV.BASE}/${CODES[Math.floor(Math.random() * CODES.length)]}`,
    { redirects: 0, headers: { "User-Agent": "Mozilla/5.0 (k6 load test) Chrome/130" } });
}
