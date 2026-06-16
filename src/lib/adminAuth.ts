const ADMIN_PASSWORD = "01278006248";

export const verifyAdminPassword = (password: string): boolean => {
  return password === ADMIN_PASSWORD;
};

export const getAdminPassword = (): string => ADMIN_PASSWORD;
