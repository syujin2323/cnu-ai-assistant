// 테스트용: 앱을 빈 포트에 띄우고 닫는다.
import { once } from "node:events";
import type { AddressInfo } from "node:net";

import type { Express } from "express";

/** app을 127.0.0.1의 빈 포트에 띄우고 기본 주소로 fn을 부른 뒤, 남은 연결까지 끊고 닫는다. */
export async function withServer<T>(
  app: Express,
  fn: (baseUrl: string) => Promise<T>,
): Promise<T> {
  const server = app.listen(0, "127.0.0.1");
  await once(server, "listening");
  try {
    const { port } = server.address() as AddressInfo;
    return await fn(`http://127.0.0.1:${port}`);
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
}
