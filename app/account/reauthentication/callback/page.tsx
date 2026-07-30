import { ReauthenticationCallbackClient } from "./ReauthenticationCallbackClient";

export const dynamic = "force-dynamic";

type CallbackQuery = {
  code?: string;
  state?: string;
  error?: string;
};

export default async function AccountReauthenticationCallbackPage({
  searchParams,
}: {
  searchParams: Promise<CallbackQuery>;
}) {
  const query = await searchParams;
  return <ReauthenticationCallbackClient
    authorizationCode={query.code}
    state={query.state}
    providerError={query.error}
  />;
}
