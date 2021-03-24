package MojoUpload;
use Mojo::Base 'Mojolicious', -signatures;

sub startup ($self) {

  # configuration
  my $config = $self->plugin('NotYAMLConfig');
  $self->secrets($config->{secrets});

  # router
  my $r = $self->routes;

  # main page
  $r->get('/')->to('upload#index');

  # upload session start/finish routes
  $r->get('/upload_start')->to('upload#start');
  $r->get('/upload_finish')->to('upload#finish');

  # routes that require an upload session
  my $u = $r->under('/' => sub ($c) {
    return 1 if $c->session('uploadid');
    $c->render(text => 'No upload in progress', status => 409);
    return undef;
  });
  $u->post('/upload')->to('upload#upload');
  $u->get('/upload')->to(cb =>
    sub($c) { $c->render(status => 204, text => '') }
  );

}

1;
