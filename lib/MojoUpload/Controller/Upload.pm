package MojoUpload::Controller::Upload;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::Path;
use File::Path qw(rmtree);
use Data::UUID;
use Fcntl;

# start upload session -- this must be called before the upload, that is
# invoking Flow.js in the frontend; the function establishes a session
# an upload id that is used to separate different uploads in the staging
# directory; this method will fail with "HTTP 409 Conflict" if there already
# is an upload session in progress

sub start ($c) {

  # already uploading, fail
  if($c->session('uploadid')) {
    $c->render(text => 'Upload already in progress', status => 409);
  }

  # not uploading, create an upload id and create a subdirectory in the staging
  # directory
  else {
    $c->session(uploadid => Data::UUID->new->create_str);
    my $dir = $c->app->home->child(
      $c->config('stagingdir'),
      $c->session('uploadid')
    );
    mkdir($dir);
    $c->render(text => 'Upload initiated, dir=' . $dir, status => 200);
  }
}

# finish upload session -- this will move the uploaded files from the staging
# directory to upload directory and expire the upload session; note, that there
# is no integrity/completeness check here - this is frontend's responsibility

sub finish ($c) {
  if($c->session('uploadid')) {
    $c->session(expires => 1);
    my $staging_dir = $c->app->home->child(
      $c->config('stagingdir'),
      $c->session('uploadid')
    );
    my $file_dir = $c->app->home->child($c->config('uploaddir'));
    for my $file ($staging_dir->list->each) {
      $file->move_to($file_dir);
    };
    rmtree($staging_dir);
    $c->render(text => 'Upload concluded', status => 200);
  } else {
    $c->render(text => 'Upload not in progress', status => 409);
  }
}

# handle upload requests -- this will receive chunk of file produced by
# Flow.js and write it into a file in the staging directory; upload session
# must be already established by the 'start' method

sub upload ($c) {

  # fail when the upload session does not exist
  return $c->render(text => 'Missing session', status => 409)
  if !$c->session('uploadid');

  # fail when the upload is too big
  return $c->render(text => 'File is too big', status => 413)
  if $c->req->is_limit_exceeded;

  # read request data
  my $chunk_size = $c->param('flowChunkSize');
  my $file_name = $c->param('flowFilename');
  my $chunk_no = $c->param('flowChunkNumber') - 1;
  my $total_size = $c->param('flowTotalSize');
  my $content = $c->param('file');

  # get the staging directory
  my $staging_dir = $c->app->home->child(
    $c->config('stagingdir'),
    $c->session('uploadid')
  );

  # target file name in the staging directory
  my $file = $staging_dir->child(sprintf("%s", $file_name));

  # read data into memory; this is possibly dangerous if the chunks are huge
  my $data = $content->slurp;
  # write the chunk into the target file
  sysopen(my $fh, $file, O_CREAT|O_WRONLY);
  if(!$fh) {
    $c->render(status => 500, text => 'Failed to open file for writing');
  }
  seek($fh, $chunk_no * $chunk_size, 0) || die;
  print $fh $data;
  close($fh);

  # finish successfully
  $c->render(status => 200, text => 'Uploaded ' . length($data) . ' bytes');

}


1;
