import {invitationLink} from '../lib/invitation-link';
export function redirectSystemPath({path}: {path: string; initial: boolean}) {
  return invitationLink(path, process.env.EXPO_PUBLIC_APP_URL);
}
