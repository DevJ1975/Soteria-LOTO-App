import jwt from 'jsonwebtoken';
import { config } from '../config/env';
import { User } from '../models/User';
import { IAuthPayload, UserRole } from '@soteria/shared';
import { AuditService } from './audit.service';
import { AuditEventType } from '@soteria/shared';

export class AuthService {
  static generateAccessToken(payload: IAuthPayload): string {
    return jwt.sign(payload, config.jwt.secret, {
      expiresIn: config.jwt.expiresIn,
    } as jwt.SignOptions);
  }

  static generateRefreshToken(payload: IAuthPayload): string {
    return jwt.sign(payload, config.jwt.refreshSecret, {
      expiresIn: config.jwt.refreshExpiresIn,
    } as jwt.SignOptions);
  }

  static verifyRefreshToken(token: string): IAuthPayload {
    return jwt.verify(token, config.jwt.refreshSecret) as IAuthPayload;
  }

  static async login(
    email: string,
    password: string,
    ipAddress?: string
  ): Promise<{ accessToken: string; refreshToken: string; user: Record<string, unknown> }> {
    // Fetch with password (select: false by default)
    const user = await User.findOne({ email: email.toLowerCase(), isActive: true }).select(
      '+password +refreshToken'
    );

    if (!user) {
      throw new Error('Invalid email or password');
    }

    const isValid = await user.comparePassword(password);
    if (!isValid) {
      throw new Error('Invalid email or password');
    }

    const payload: IAuthPayload = {
      userId: user._id.toString(),
      email: user.email,
      role: user.role,
      companyId: user.companyId.toString(),
      siteIds: user.siteIds.map((id) => id.toString()),
    };

    const accessToken = AuthService.generateAccessToken(payload);
    const refreshToken = AuthService.generateRefreshToken(payload);

    // Persist refresh token hash
    user.refreshToken = refreshToken;
    user.lastLoginAt = new Date();
    await user.save();

    await AuditService.log({
      eventType: AuditEventType.USER_LOGIN,
      companyId: user.companyId.toString(),
      userId: user._id.toString(),
      description: `User ${user.email} logged in`,
      ipAddress,
    });

    const userObj = user.toJSON();
    return { accessToken, refreshToken, user: userObj };
  }

  static async refresh(refreshToken: string): Promise<{ accessToken: string }> {
    let payload: IAuthPayload;
    try {
      payload = AuthService.verifyRefreshToken(refreshToken);
    } catch {
      throw new Error('Invalid or expired refresh token');
    }

    const user = await User.findById(payload.userId)
      .select('+refreshToken')
      .where({ isActive: true });

    if (!user || user.refreshToken !== refreshToken) {
      throw new Error('Refresh token revoked');
    }

    const newPayload: IAuthPayload = {
      userId: user._id.toString(),
      email: user.email,
      role: user.role,
      companyId: user.companyId.toString(),
      siteIds: user.siteIds.map((id) => id.toString()),
    };

    return { accessToken: AuthService.generateAccessToken(newPayload) };
  }

  static async logout(userId: string): Promise<void> {
    await User.findByIdAndUpdate(userId, { $unset: { refreshToken: 1 } });
  }
}
