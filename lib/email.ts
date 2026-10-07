import "server-only";
import { Resend } from "resend";

/** Call only from trusted server workflows after validating the recipient. */
export async function sendTransactionalEmail(input: {
  to: string;
  from?: string;
  subject: string;
  text: string;
  idempotencyKey: string;
}) {
  const apiKey = process.env.RESEND_API_KEY;
  const from = input.from || process.env.RESEND_FROM_EMAIL;
  if (!apiKey || !from) {
    throw new Error("Email requires RESEND_API_KEY and a verified RESEND_FROM_EMAIL.");
  }

  const resend = new Resend(apiKey);
  const { data, error } = await resend.emails.send(
    { from, to: input.to, subject: input.subject, text: input.text },
    { idempotencyKey: input.idempotencyKey },
  );
  if (error) throw new Error(`Email delivery request failed: ${error.name}`);
  if (!data) throw new Error("Email provider returned no delivery ID.");
  return data;
}

/** Business notifications always go to the configured enquiry inbox. */
export async function sendEnquiryNotification(input: {
  subject: string;
  text: string;
  idempotencyKey: string;
}) {
  const to = process.env.ENQUIRY_TO_EMAIL;
  if (!to) throw new Error("Enquiry notifications require ENQUIRY_TO_EMAIL.");
  return sendTransactionalEmail({ ...input, to });
}
