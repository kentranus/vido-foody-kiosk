import React, { useState, useEffect } from 'react';
import { X, Lock } from 'lucide-react';
import { C } from '../theme';
import { verifyPin, verifyManagerPin, setCurrentStaff } from '../services/staffStorage';

// =====================================================================
// MODAL WRAPPER
// =====================================================================
export function Modal({ onClose, children, maxWidth = 540 }) {
  return (
    <div style={mStyles.overlay} onClick={onClose}>
      <div style={{ ...mStyles.body, maxWidth }} onClick={e => e.stopPropagation()}>
        {children}
      </div>
    </div>
  );
}

export function ModalClose({ onClose }) {
  return (
    <button onClick={onClose} style={mStyles.close} aria-label="Close">
      <X size={18} />
    </button>
  );
}

const mStyles = {
  overlay: {
    position: 'fixed', inset: 0,
    background: C.overlay,
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    zIndex: 1000, padding: 20,
  },
  body: {
    background: C.panel,
    borderRadius: 18,
    width: '100%',
    maxHeight: '90vh',
    overflow: 'auto',
    position: 'relative',
    boxShadow: '0 20px 60px rgba(0,0,0,0.5)',
  },
  close: {
    position: 'absolute', top: 14, right: 14,
    width: 34, height: 34,
    background: C.card, color: C.text,
    border: 'none', borderRadius: 999,
    cursor: 'pointer', zIndex: 1,
    display: 'flex', alignItems: 'center', justifyContent: 'center',
  },
};

// =====================================================================
// PIN LOCK
// =====================================================================
export function PinLockScreen({ title, subtitle, managerOnly = false, fullScreen = true, onUnlock, onCancel }) {
  const [pin, setPin] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (pin.length === 4) {
      submit();
    }
    // eslint-disable-next-line
  }, [pin]);

  const press = (d) => {
    if (busy) return;
    setError('');
    if (pin.length < 4) setPin(pin + d);
  };
  const backspace = () => { setError(''); setPin(pin.slice(0, -1)); };

  const submit = async () => {
    if (pin.length < 4) return;
    setBusy(true);
    setError('');
    try {
      const staff = managerOnly ? await verifyManagerPin(pin) : await verifyPin(pin);
      if (staff) {
        if (!managerOnly) setCurrentStaff(staff);
        onUnlock(staff);
      } else {
        setError(managerOnly ? 'Manager PIN required' : 'Invalid PIN');
        setPin('');
      }
    } catch (e) {
      setError(e.message);
      setPin('');
    } finally {
      setBusy(false);
    }
  };

  const Container = fullScreen ? FullScreen : Modal;

  return (
    <Container onClose={onCancel}>
      <div style={pStyles.card}>
        <div style={pStyles.iconWrap}>F</div>
        <div style={pStyles.title}>{title || 'Enter PIN'}</div>
        <div style={pStyles.subtitle}>{subtitle || 'Sign in to continue'}</div>
        <div style={pStyles.dots}>
          {[0,1,2,3].map(i => (
            <div key={i} style={{ ...pStyles.dot, background: i < pin.length ? C.primary : C.card }} />
          ))}
        </div>
        {error && <div style={pStyles.error}>{error}</div>}
        <div style={pStyles.pad}>
          {[1,2,3,4,5,6,7,8,9].map(d => (
            <button key={d} onClick={() => press(d)} style={pStyles.key}>{d}</button>
          ))}
          {onCancel ? (
            <button onClick={onCancel} style={{ ...pStyles.key, color: C.red, fontSize: 13 }}>Cancel</button>
          ) : <div style={pStyles.key} />}
          <button onClick={() => press(0)} style={pStyles.key}>0</button>
          <button onClick={backspace} style={{ ...pStyles.key, fontSize: 18 }}>⌫</button>
        </div>
        {!managerOnly && fullScreen && (
          <div style={pStyles.hint}>Default Manager: 1234 · Cashier: 0000</div>
        )}
      </div>
    </Container>
  );
}

function FullScreen({ children }) {
  return <div style={pStyles.overlay}>{children}</div>;
}

const pStyles = {
  overlay: {
    position: 'fixed', inset: 0,
    background: C.bg,
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    zIndex: 2000,
  },
  card: {
    background: C.panel, borderRadius: 24,
    padding: '32px 40px', width: 360,
    boxShadow: `0 20px 60px ${C.shadow}`,
  },
  iconWrap: {
    width: 64, height: 64, borderRadius: 18,
    background: C.primaryG,
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    margin: '0 auto 18px',
    fontSize: 36, fontWeight: 900, color: '#fff',
    fontFamily: 'Arial Black, sans-serif',
    boxShadow: C.primaryGShadow,
    letterSpacing: -1,
  },
  title: { textAlign: 'center', fontSize: 22, fontWeight: 900, color: C.text, marginBottom: 4 },
  subtitle: { textAlign: 'center', fontSize: 13, fontWeight: 700, color: C.textMute, marginBottom: 24 },
  dots: { display: 'flex', gap: 14, justifyContent: 'center', margin: '0 0 18px' },
  dot: { width: 16, height: 16, borderRadius: 999, transition: 'background 0.15s' },
  error: {
    background: C.redA, color: C.red,
    padding: '8px 12px', borderRadius: 8,
    textAlign: 'center', fontWeight: 800, fontSize: 12,
    marginBottom: 14,
  },
  pad: { display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 },
  key: {
    height: 56, background: C.card, color: C.text,
    border: 'none', borderRadius: 14,
    fontSize: 22, fontWeight: 800, cursor: 'pointer',
  },
  hint: {
    textAlign: 'center', fontSize: 10, color: C.textDim,
    fontWeight: 700, marginTop: 18, fontStyle: 'italic',
  },
};

// =====================================================================
// SHARED BUTTONS
// =====================================================================
export function Button({ variant = 'primary', size = 'md', children, style, ...props }) {
  const sizes = {
    sm: { padding: '6px 12px', fontSize: 12 },
    md: { padding: '10px 16px', fontSize: 13 },
    lg: { padding: '14px 22px', fontSize: 15 },
  };
  const variants = {
    primary: {
      background: C.primary, color: C.bg,
      boxShadow: `0 3px 0 ${C.primaryD}`,
    },
    secondary: { background: C.card, color: C.text },
    danger: { background: C.red, color: '#fff' },
    ghost: { background: 'transparent', color: C.text, border: `1px solid ${C.border}` },
  };
  return (
    <button
      style={{
        border: 'none', borderRadius: 10, cursor: 'pointer',
        fontWeight: 800, fontFamily: 'inherit',
        ...sizes[size], ...variants[variant], ...style,
      }}
      {...props}
    >{children}</button>
  );
}

export function Input({ style, ...props }) {
  return (
    <input
      style={{
        width: '100%', padding: '10px 14px',
        background: C.card, color: C.text,
        border: `1px solid ${C.border}`,
        borderRadius: 10, fontSize: 14, fontWeight: 700,
        fontFamily: 'inherit', outline: 'none',
        ...style,
      }}
      {...props}
    />
  );
}

export function Field({ label, children, hint }) {
  return (
    <div style={{ marginBottom: 14 }}>
      <div style={{ fontSize: 11, fontWeight: 800, color: C.textMute, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6 }}>
        {label}
      </div>
      {children}
      {hint && <div style={{ fontSize: 11, color: C.textMute, fontWeight: 700, marginTop: 4 }}>{hint}</div>}
    </div>
  );
}
