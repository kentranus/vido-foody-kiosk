import { getJSON, setJSON } from './storage';

const CONFIG_KEY = 'vido_order_hub_config';

const DEFAULT_CONFIG = {
  enabled: false,
  hubUrl: 'http://127.0.0.1:8787',
  storeId: 'vido-foody',
  stationId: 'pos-1',
  autoAcceptKioskOrders: true,
  autoPrintKitchenTickets: true,
  autoPrintCustomerReceipts: false,
  kioskPax: {
    enabled: true,
    connectionMode: 'tcp',
    terminalSerial: '',
    ip: '',
    port: 10009,
    timeout: 60000,
    tipRequest: true,
    usePosLinkSdk: true,
  },
};

function cleanUrl(url) {
  return String(url || '').replace(/\/+$/, '');
}

async function requestJson(url, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), options.timeout || 8000);
  try {
    const res = await fetch(url, {
      ...options,
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        ...(options.headers || {}),
      },
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || `Hub request failed (${res.status})`);
    return data;
  } finally {
    clearTimeout(timeout);
  }
}

class OrderHubService {
  constructor() {
    this.config = { ...DEFAULT_CONFIG };
    this.ready = this._loadConfig();
  }

  async _loadConfig() {
    const saved = await getJSON(CONFIG_KEY, null);
    if (saved) {
      this.config = {
        ...DEFAULT_CONFIG,
        ...saved,
        kioskPax: { ...DEFAULT_CONFIG.kioskPax, ...(saved.kioskPax || {}) },
      };
    }
  }

  async updateConfig(cfg) {
    await this.ready;
    this.config = { ...this.config, ...cfg };
    await setJSON(CONFIG_KEY, this.config);
    return this.config;
  }

  async ping(cfg = this.config) {
    await this.ready;
    const base = cleanUrl(cfg.hubUrl);
    if (!base) return { ok: false, error: 'Hub URL is empty' };
    try {
      const data = await requestJson(`${base}/health`, { method: 'GET', timeout: 5000 });
      return { ok: true, ...data };
    } catch (e) {
      return { ok: false, error: e.message || 'Order hub offline' };
    }
  }

  async submitOrder(order, extra = {}) {
    await this.ready;
    if (!this.config.enabled) return { ok: false, skipped: true, order };
    const base = cleanUrl(this.config.hubUrl);
    const payload = {
      order,
      storeId: this.config.storeId,
      stationId: extra.stationId || this.config.stationId,
      source: extra.source || order.source || 'kiosk',
    };
    return requestJson(`${base}/api/stores/${encodeURIComponent(this.config.storeId)}/orders`, {
      method: 'POST',
      body: JSON.stringify(payload),
      timeout: 10000,
    });
  }

  async fetchOrders({ status = 'paid', since } = {}) {
    await this.ready;
    if (!this.config.enabled) return { ok: false, skipped: true, orders: [] };
    const base = cleanUrl(this.config.hubUrl);
    const qs = new URLSearchParams();
    if (status) qs.set('status', status);
    if (since) qs.set('since', since);
    return requestJson(`${base}/api/stores/${encodeURIComponent(this.config.storeId)}/orders?${qs.toString()}`, {
      method: 'GET',
      timeout: 8000,
    });
  }

  async updateOrderStatus(orderId, status, updates = {}) {
    await this.ready;
    if (!this.config.enabled) return { ok: false, skipped: true };
    const base = cleanUrl(this.config.hubUrl);
    return requestJson(`${base}/api/stores/${encodeURIComponent(this.config.storeId)}/orders/${encodeURIComponent(orderId)}`, {
      method: 'PATCH',
      body: JSON.stringify({ status, ...updates }),
      timeout: 8000,
    });
  }
}

export const orderHubService = new OrderHubService();
