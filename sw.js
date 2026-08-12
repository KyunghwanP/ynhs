const CACHE_NAME = 'ynhs-v495';

self.addEventListener('install', e => {
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)));
    await self.clients.claim();
  })());
});

// ── 캐시 우선 + 배경 갱신(stale-while-revalidate) ──────────────────────────
//  이전(network-first)의 문제:
//   · 매 요청이 네트워크를 먼저 기다려 → 망이 느리거나 끊기면 페이지가 멈춤.
//   · 네트워크 실패 시 caches.match()로 폴백하는데, 위젯 URL엔 매번 다른
//     ?t=타임스탬프(캐시버스터)가 붙어 캐시 키가 안 맞음 → undefined 반환
//     → 브라우저가 ERR_FAILED로 처리(그래서 '되다 안 되다'·자주 멈춤).
//  바뀐 동작:
//   · 캐시에 있으면 '즉시' 반환 → 네트워크가 느리거나 끊겨도 화면이 멈추거나
//     ERR_FAILED가 나지 않는다. 배경에서 네트워크로 최신본을 받아 캐시를 갱신
//     → 다음 로드는 최신.
//   · 네비게이션(HTML 문서)은 ?t= 등 쿼리가 매번 달라도 같은 화면이므로,
//     캐시 키를 '경로(pathname)'로 정규화해 매칭을 보장하고 캐시 무한증식을 막는다.
//   · 캐시도 없고 네트워크도 실패하면 undefined가 아니라 명확한 503을 반환
//     (respondWith(undefined)로 인한 ERR_FAILED 방지).
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;      // 외부(CDN 등)는 미개입
  if (url.pathname.includes('/docs/')) return;          // 대용량 PDF는 브라우저가 직접 처리

  const isNav = req.mode === 'navigate';
  // 네비게이션은 쿼리(?widget=…&t=…)를 무시하고 경로로 캐시 → 화면 종류는 페이지 JS가
  // location.search를 읽어 그림. 그 외 자원은 정확한 URL로 캐시.
  const cacheKey = isNav ? new Request(url.origin + url.pathname) : req;

  e.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(cacheKey);

    // 배경(또는 캐시 미스 시 대기용) 네트워크 갱신. 실패해도 null만 돌려주고 절대 던지지 않는다.
    const fromNet = fetch(req).then(res => {
      if (res && res.ok && res.status === 200) {
        cache.put(cacheKey, res.clone()).catch(() => {});
      }
      return res;
    }).catch(() => null);

    if (cached) {
      e.waitUntil(fromNet);   // 즉시 캐시 반환 + 배경 갱신(대기 안 함)
      return cached;
    }

    // 캐시에 없으면 네트워크를 기다린다.
    const res = await fromNet;
    if (res) return res;

    // 네트워크도 실패 + 캐시도 없음 → undefined 대신 명확한 응답(ERR_FAILED 방지).
    if (isNav) {
      const shell = await cache.match(new Request(url.origin + '/ynhs/'))
                 || await cache.match(new Request(url.origin + '/ynhs/index.html'));
      if (shell) return shell;
    }
    return new Response('오프라인 상태이고 캐시된 내용이 없습니다. 잠시 후 다시 시도해 주세요.', {
      status: 503, statusText: 'Offline',
      headers: { 'Content-Type': 'text/plain; charset=utf-8' }
    });
  })());
});

self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
      for (const c of list) { if ('focus' in c) return c.focus(); }
      return clients.openWindow('./');
    })
  );
});
