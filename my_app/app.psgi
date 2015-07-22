# app.psgi
use v5.10;
use JSON::RPC::Lite;

#my $filename = "log.txt";
#open my $log_fh, ">", $filename or die "Cannot open $filename";
#$log_fh->autoflush(1);
STDOUT->autoflush(1);
STDERR->autoflush(1);

method 'sum' => sub {
  my $a = $_[0]->{a};
  my $b = $_[0]->{b};
  #say $log_fh "sum called with parameters ($a, $b)";
  say "sum called with parameters ($a, $b)";
  return $a + $b;
};

method 'stop' => sub {
  #say $log_fh "Stopping";
  say "Stopping";
  exit;
};


as_psgi_app;