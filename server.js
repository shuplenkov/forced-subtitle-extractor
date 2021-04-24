const util = require('util');
const exec = util.promisify(require('child_process').exec);
const Koa = require('koa');
const Router = require('@koa/router');
const multer = require('@koa/multer');
const Queue = require('queue-promise');

const PORT = 3000;

const queue = new Queue({
  concurrent: 1,
  interval: 2000
});
const app = new Koa();
const router = new Router();
const upload = multer();
const runScript = async () => {
  const { stdout, stderr } = await exec('bash /extractForcedSubtitles.sh');

  if (stderr) {
    throw new Error(stderr);
  }

  return stdout;
};

queue.on('resolve', data => console.log(data));
queue.on('reject', error => console.error(error));

// for debug purposes
router.get('/', (ctx) => {
  queue.enqueue(runScript);

  ctx.body = 'done';
});

router.post('/', upload.single('thumb'), (ctx) => {
  try {
    const payload = JSON.parse(ctx.request.body.payload);

    if (payload.event === 'library.new') {
      // run bash script
      queue.enqueue(runScript);
    }
  } catch (e) {
    console.error(e);
  }

  ctx.body = 'done';
});

app.use(router.routes());
app.use(router.allowedMethods());

app.listen(PORT);

console.info(`Web server was started at ${PORT} port`);
