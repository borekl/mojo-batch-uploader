// commence uploading session; this function must be invoked before starting
// Flow.js upload; without this the chunks will be refused

function start_upload()
{
  return new Promise((resolve, reject) => {
    fetch('/upload_start').then(response => {
      if(response.status == 200) resolve();
      else reject(response.statusText);
    });
  })
}

// complete current uploading session; this must be called after all files
// uploaded; otherwise they will not be accepted by the backend

function finish_upload()
{
  return new Promise((resolve, reject) => {
    fetch('/upload_finish').then(response => {
      if(response.status == 200) resolve();
      else reject(response.statusText);
    })
  })
}

// upload files; just a wrapper function so that we can await Flow.js's
// own upload() method

function upload(flow)
{
  let p = new Promise((resolve) => {
    flow.on('complete', () => resolve());
  });
  flow.upload();
  return p;
}

// MAIN

document.addEventListener("DOMContentLoaded", () => {

  // set up a Flow.js instance

  let r = new Flow({
    target: '/upload',
    query: { upload_token: 'mojo_upload' },
    testChunks: false,
    chunkSize: 4096,
  });

  if(!r.support) { throw new Error('Flow.js is not supported here') }

  // documentation says 409 is by default a permanent error, but in fact
  // it's not, so we need to add it.
  r.opts.permanentErrors.push(409);

  // define our vue.js frontend

  const app = Vue.createApp({

    mounted() {
      r.assignBrowse(document.getElementById('browse'));
      r.assignDrop(document.getElementById('droptarget'));
      r.on('fileAdded', (file) => this.add_file(file));
      r.on('fileSuccess', (file) => this.file_find(
        file, f => f.completed = true
      ));
      r.on('progress', () => { this.progress = r.progress() });
      r.on('fileProgress', (file) => this.file_find(
        file, f => f.progress = file.progress()
      ));
    },

    data() {
      return {
        files: [],
        progress: 0,
        uploading: false,
        retriable: false,
        completed: false,
        cancelling: false,
      }
    },

    methods: {
      async start_upload() {
        try {
          this.completed = false;
          this.uploading = false;
          this.completed = false;
          await start_upload();
          this.uploading = true;
          await upload(r);
          if(this.failed_no) {
            console.log('Upload partially finished');
            this.retriable = true;
            this.uploading = false;
          } else {
            this.retriable = false;
            await finish_upload();
            this.uploading = false;
            this.completed = true;
            console.log('Upload finished successfully');
          }
        } catch(err) {
          console.log(err);
          this.uploading = false;
        }
      },
      retry() {
        /*console.debug('Upload retry requested');
        failed_new = failed.map(x => x);
        failed = [];
        failed_new.forEach(f => f.retry());*/
      },
      add_file(file) {
        let frec = {
          rfile: file,        // FlowFile reference
          completed: false,   // file uploaded successfully
          failed: false,      // file failed to upload
          progress: 0,        // upload progress (float)
        }
        this.files.push(frec)
      },
      file_find(file, cb) {
        let idx = this.files.findIndex(
          f => f.rfile.uniqueIdentifier == file.uniqueIdentifier
        );
        if(idx != -1) cb(this.files[idx]);
      },
      reset() {
        this.files = [];
        this.completed = false;
        this.uploading = false;
        this.retriable = false;
        this.progress = 0;
        r.cancel();
      }
    },

    computed: {
      failed_no() { return this.files.filter(f => f.failed).length },
      completed_no() { return this.files.filter(f => f.completed).length }
    }

  });

  // simple progress bar component

  app.component('progress-bar', {
    props: [ 'value', 'width', 'padding', 'margin' ],
    template: `
      <div class="pgbar-container" :style="{margin:margin || 'auto'}">
        <div class="pgbar-message"
          :style="{ width: width, padding: padding || '1em' }"
        >
          <slot>{{ value + '%' }}</slot>
        </div>
        <div class="pgbar-fill" :style="{ width: value + '%' }">
        </div>
      </div>
    `
  });

  // run the app

  app.mount('#vuejsapp');

});
