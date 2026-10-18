import { setupWorker } from "msw/browser";
import { handlers } from "./handlers";

const worker = setupWorker(...handlers);
let started: Promise<unknown> | null = null;

// React の StrictMode は開発時に effect を2回実行するため、起動は1回だけにする
export function startMocking() {
  started ??= worker.start({ onUnhandledRequest: "bypass" });
  return started;
}
