import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';

export function LoginPage() {
  const navigate = useNavigate();
  const login = useAuthStore(s => s.login);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true); setError('');
    try {
      await login(email, password);
      navigate('/');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#1A1A1A', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div style={{ backgroundColor: '#FFF', borderRadius: 10, padding: '36px 40px', width: '100%', maxWidth: 400, boxShadow: '0 4px 20px rgba(0,0,0,0.3)' }}>
        <div style={{ textAlign: 'center', marginBottom: 28 }}>
          <div style={{ fontSize: 32, color: '#CC0000', fontWeight: 900, letterSpacing: 2 }}>⚠ SOTERIA</div>
          <div style={{ fontSize: 12, color: '#888', marginTop: 4, letterSpacing: 1 }}>LOCKOUT / TAGOUT ADMIN PORTAL</div>
        </div>
        {error && <div style={{ backgroundColor: '#FFEBEE', color: '#CC0000', padding: '10px 14px', borderRadius: 6, marginBottom: 16, fontSize: 13 }}>{error}</div>}
        <form onSubmit={handleSubmit}>
          <label style={{ fontSize: 11, fontWeight: 700, color: '#555', textTransform: 'uppercase', letterSpacing: 0.5 }}>Email</label>
          <input type="email" value={email} onChange={e => setEmail(e.target.value)} required
            style={{ display: 'block', width: '100%', border: '1.5px solid #CCC', borderRadius: 6, padding: '10px 12px', fontSize: 15, marginBottom: 16, boxSizing: 'border-box', marginTop: 5 }} />
          <label style={{ fontSize: 11, fontWeight: 700, color: '#555', textTransform: 'uppercase', letterSpacing: 0.5 }}>Password</label>
          <input type="password" value={password} onChange={e => setPassword(e.target.value)} required
            style={{ display: 'block', width: '100%', border: '1.5px solid #CCC', borderRadius: 6, padding: '10px 12px', fontSize: 15, marginBottom: 22, boxSizing: 'border-box', marginTop: 5 }} />
          <button type="submit" disabled={loading}
            style={{ width: '100%', backgroundColor: '#CC0000', color: '#FFF', border: 'none', borderRadius: 6, padding: '12px', fontSize: 15, fontWeight: 700, cursor: 'pointer', letterSpacing: 1.5 }}>
            {loading ? 'Signing In...' : 'SIGN IN'}
          </button>
        </form>
      </div>
    </div>
  );
}
