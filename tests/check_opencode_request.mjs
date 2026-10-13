// Optional integration check: real OpenCode, simulated OpenRouter, no paid requests.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { copyFile, mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { homedir, tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const scratch = await mkdtemp(join(tmpdir(), 'delegate-request-'));
const requests = [];
let rejectEffort = false;
const server = createServer(async (req, res) => {
  try {
    let raw = '';
    for await (const chunk of req) raw += chunk;
    const body = JSON.parse(raw);
    requests.push(body);
    if (rejectEffort && body.tools?.length) {
      res.writeHead(400, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: { message: 'coreweave/nvfp4 unavailable', code: 400 } }));
      return;
    }
    res.writeHead(200, { 'content-type': 'text/event-stream' });
    for (const [delta, finish] of [[{ role: 'assistant', content: 'Request checked.' }, null], [{}, 'stop']]) {
      res.write(`data: ${JSON.stringify({
        id: 'chatcmpl-local', object: 'chat.completion.chunk', created: 1,
        model: body.model,
        choices: [{ index: 0, delta, finish_reason: finish }],
        ...(finish ? { usage: { prompt_tokens: 20, completion_tokens: 5, total_tokens: 25 } } : {}),
      })}\n\n`);
    }
    res.end('data: [DONE]\n\n');
  } catch (error) {
    res.writeHead(400);
    res.end(String(error));
  }
});

function run(args, env, command = 'opencode', expectedCode = 0) {
  return new Promise((resolveRun, reject) => {
    const child = spawn(command, args, { cwd: join(scratch, 'repo'), env, stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '', stderr = '';
    child.stdout.on('data', (data) => { stdout += data; });
    child.stderr.on('data', (data) => { stderr += data; });
    const timer = setTimeout(() => { child.kill('SIGKILL'); }, 45000);
    child.on('error', (error) => { clearTimeout(timer); reject(error); });
    child.on('close', (code, signal) => {
      clearTimeout(timer);
      if (code !== expectedCode) reject(new Error(`Expected exit ${expectedCode}, got ${code ?? signal}\n${stderr}\n${stdout}`));
      else resolveRun(stdout);
    });
  });
}

try {
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const configDir = join(scratch, 'config', 'opencode');
  await mkdir(join(configDir, 'agents'), { recursive: true });
  await mkdir(join(scratch, 'repo'));
  await mkdir(join(scratch, 'cache', 'opencode'), { recursive: true });
  await copyFile(join(root, 'delegate', 'opencode', 'delegate-executor.md'), join(configDir, 'agents', 'delegate-executor.md'));
  const cachedModels = join(process.env.XDG_CACHE_HOME || join(homedir(), '.cache'), 'opencode', 'models.json');
  try {
    await copyFile(cachedModels, join(scratch, 'cache', 'opencode', 'models.json'));
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  await writeFile(join(configDir, 'opencode.json'), JSON.stringify({
    enabled_providers: ['openrouter'],
    model: 'openrouter/z-ai/glm-5.3-flash',
    small_model: 'openrouter/z-ai/glm-5.3-flash',
    provider: { openrouter: {
      // Auto must preserve this route; an explicit endpoint must override it.
      models: { 'z-ai/glm-5.3-flash': { options: {
        reasoningEffort: 'xhigh',
        provider: { order: ['relace/fp4'], only: ['relace/fp4'], allow_fallbacks: false },
      } } },
      options: { apiKey: 'local-test-only', baseURL: `http://127.0.0.1:${server.address().port}/v1` },
    } },
  }));
  // A fresh environment prevents loading credentials, plugins or personal config.
  const env = {
    PATH: process.env.PATH,
    HOME: join(scratch, 'home'),
    XDG_CONFIG_HOME: join(scratch, 'config'),
    XDG_DATA_HOME: join(scratch, 'data'),
    XDG_CACHE_HOME: join(scratch, 'cache'),
    XDG_STATE_HOME: join(scratch, 'state'),
    OPENCODE_CONFIG_DIR: configDir,
    OPENCODE_DISABLE_MODELS_FETCH: '1',
    OPENCODE_DISABLE_AUTOUPDATE: '1',
    OPENCODE_DISABLE_DEFAULT_PLUGINS: '1',
    OPENCODE_DISABLE_EXTERNAL_SKILLS: '1',
    OPENCODE_DISABLE_CLAUDE_CODE: '1',
    OPENCODE_DISABLE_LSP_DOWNLOAD: '1',
    OPENROUTER_API_KEY: 'local-test-only',
    DELEGATE_HOST: 'codex',
    DELEGATE_STATE_DIR: join(scratch, 'delegate-state'),
    DELEGATE_CONFIG: join(scratch, 'delegate-config'),
  };
  const resolved = JSON.parse(await run(['debug', 'agent', 'delegate-executor'], env));
  assert.equal(resolved.model, undefined, 'Generic agent must not pin a model');
  assert.equal(resolved.options.provider, undefined, 'Generic agent must not pin CoreWeave');
  const brief = join(scratch, 'brief.md');
  await writeFile(brief, 'Return exactly "Request checked." Do not use tools or edit any files.');
  const script = join(root, 'delegate', 'bin', 'delegate');
  const args = [script, 'run', '--check', 'true', brief];
  async function executorRequest(runEnv = env) {
    const before = requests.length;
    const output = await run(args, runEnv, 'bash');
    assert.match(output, /Request checked/);
    const request = requests.slice(before).find((body) => body.tools?.length);
    assert.ok(request, 'No executor request was captured');
    return request;
  }
  const automatic = await executorRequest();
  assert.equal(automatic.model, 'z-ai/glm-5.3-flash');
  assert.equal(automatic.reasoning?.effort, 'max');
  assert.deepEqual(automatic.provider?.order, ['relace/fp4']);
  assert.deepEqual(automatic.provider?.only, ['relace/fp4']);
  assert.ok(!JSON.stringify(automatic.provider).includes('coreweave'), 'Default forced CoreWeave');
  await run([script, 'provider', 'coreweave/nvfp4'], env, 'bash');
  const request = await executorRequest();
  assert.equal(request.model, 'z-ai/glm-5.3-flash');
  assert.equal(request.reasoning?.effort, 'max');
  assert.deepEqual(request.provider?.order, ['coreweave/nvfp4']);
  assert.deepEqual(request.provider?.only, ['coreweave/nvfp4']);
  assert.equal(request.provider.allow_fallbacks, false);
  assert.equal(request.provider.require_parameters, true);
  const otherEnv = { ...env, DELEGATE_MODEL: 'openrouter/deepseek/deepseek-v4.1-flash' };
  const other = await executorRequest(otherEnv);
  assert.equal(other.model, 'deepseek/deepseek-v4.1-flash');
  assert.equal(other.reasoning?.effort, 'high');
  assert.ok(!JSON.stringify(other.provider ?? {}).includes('coreweave'), 'CoreWeave leaked to another model');
  await run([script, 'provider', 'deepinfra/turbo'], otherEnv, 'bash');
  const otherExplicit = await executorRequest(otherEnv);
  assert.deepEqual(otherExplicit.provider?.order, ['deepinfra/turbo']);
  assert.deepEqual(otherExplicit.provider?.only, ['deepinfra/turbo']);
  assert.equal(otherExplicit.provider.allow_fallbacks, false);
  assert.equal(otherExplicit.provider.require_parameters, true);
  const restored = await executorRequest();
  assert.deepEqual(restored.provider?.only, ['coreweave/nvfp4']);
  await run([script, 'provider', 'auto'], env, 'bash');
  const reset = await executorRequest();
  assert.deepEqual(reset.provider?.order, ['relace/fp4']);
  assert.deepEqual(reset.provider?.only, ['relace/fp4']);
  assert.equal(reset.provider.require_parameters, undefined);
  await run([script, 'provider', 'coreweave/nvfp4'], env, 'bash');
  rejectEffort = true;
  const rejected = await run(args, env, 'bash', 1);
  assert.match(rejected, /executor error: .*coreweave\/nvfp4 unavailable/);
  assert.match(rejected, /check exit: 0/);
  console.log('Verified inherited routing, explicit per-model endpoints, model switching, auto reset, and nonzero exit on executor errors.');
} finally {
  server.closeAllConnections();
  await new Promise((done) => server.close(done));
  await rm(scratch, { recursive: true, force: true });
}
