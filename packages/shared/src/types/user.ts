import { UserRole } from './enums';

export interface IUser {
  _id: string;
  email: string;
  firstName: string;
  lastName: string;
  role: UserRole;
  companyId: string;
  siteIds: string[]; // sites this user has access to (empty = all sites for company)
  isActive: boolean;
  lastLoginAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface IUserWithToken extends IUser {
  accessToken: string;
  refreshToken: string;
}

export type CreateUserDto = Pick<IUser, 'email' | 'firstName' | 'lastName' | 'role' | 'companyId' | 'siteIds'> & {
  password: string;
};

export type UpdateUserDto = Partial<Pick<IUser, 'firstName' | 'lastName' | 'role' | 'siteIds' | 'isActive'>>;

export interface IAuthPayload {
  userId: string;
  email: string;
  role: UserRole;
  companyId: string;
  siteIds: string[];
}
