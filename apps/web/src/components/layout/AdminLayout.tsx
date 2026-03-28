import React, { useState } from 'react';
import { Outlet, NavLink, useNavigate } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';

const NAV_ITEMS = [
  { to: '/', label: 'Dashboard', exact: true },
  { to: '/placards', label: 'Placards' },
  { to: '/approvals', label: 'Approvals' },
  { to: '/equipment', label: 'Equipment' },
  { to: '/sites', label: 'Sites' },
  { to: '/audit', label: 'Audit Trail' },
];

export function AdminLayout() {
  const user = useAuthStore((s) => s.user);
  const logout = useAuthStore((s) => s.logout);
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  return (
    <div style={styles.shell}>
      {/* Sidebar */}
      <aside style={styles.sidebar}>
        {/* Logo/brand */}
        <div style={styles.brand}>
          <div style={styles.brandIcon}>⚠</div>
          <div>
            <div style={styles.brandName}>SOTERIA LOTO</div>
            <div style={styles.brandSub}>Admin Portal</div>
          </div>
        </div>

        {/* Navigation */}
        <nav style={styles.nav}>
          {NAV_ITEMS.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.exact}
              style={({ isActive }) => ({
                ...styles.navItem,
                ...(isActive ? styles.navItemActive : {}),
              })}
            >
              {item.label}
            </NavLink>
          ))}
        </nav>

        {/* User info */}
        <div style={styles.userBlock}>
          <div style={styles.userName}>
            {user?.firstName} {user?.lastName}
          </div>
          <div style={styles.userRole}>{user?.role?.replace(/_/g, ' ').toUpperCase()}</div>
          <button style={styles.logoutBtn} onClick={handleLogout}>Sign Out</button>
        </div>
      </aside>

      {/* Main content */}
      <main style={styles.main}>
        <Outlet />
      </main>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  shell: { display: 'flex', height: '100vh', overflow: 'hidden' },
  sidebar: {
    width: 220,
    backgroundColor: '#1A1A1A',
    display: 'flex',
    flexDirection: 'column',
    flexShrink: 0,
  },
  brand: {
    padding: '20px 16px',
    borderBottom: '1px solid #333',
    display: 'flex',
    alignItems: 'center',
    gap: 10,
  },
  brandIcon: { fontSize: 24, color: '#CC0000' },
  brandName: { color: '#FFFFFF', fontWeight: 900, fontSize: 14, letterSpacing: 2 },
  brandSub: { color: '#888', fontSize: 10, marginTop: 1 },
  nav: { flex: 1, padding: '12px 0', overflowY: 'auto' },
  navItem: {
    display: 'block',
    padding: '11px 20px',
    color: '#AAAAAA',
    textDecoration: 'none',
    fontSize: 13,
    fontWeight: 500,
    transition: 'background 0.15s',
  },
  navItemActive: {
    color: '#FFFFFF',
    backgroundColor: '#CC0000',
    borderRight: '3px solid #FF6B6B',
  },
  userBlock: {
    padding: 16,
    borderTop: '1px solid #333',
  },
  userName: { color: '#FFF', fontWeight: 600, fontSize: 13 },
  userRole: { color: '#888', fontSize: 10, marginTop: 2, letterSpacing: 0.5 },
  logoutBtn: {
    marginTop: 10,
    background: 'transparent',
    border: '1px solid #555',
    color: '#AAA',
    padding: '5px 10px',
    borderRadius: 4,
    cursor: 'pointer',
    fontSize: 11,
    width: '100%',
  },
  main: { flex: 1, overflowY: 'auto', padding: 24 },
};
