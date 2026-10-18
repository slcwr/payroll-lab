import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Cloud Run 用に依存込みの最小構成で出力する
  output: "standalone",
  reactStrictMode: true,
  transpilePackages: ["smarthr-ui"],
  agentRules: false,
};

export default nextConfig;
