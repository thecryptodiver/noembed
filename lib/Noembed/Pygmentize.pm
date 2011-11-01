package Noembed::Pygmentize;

use Carp;
use IPC::Open3;
use File::Which qw/which/;
use List::Util qw/first/;
use Symbol 'gensym'; 

sub new {
  my ($class, %args) = @_;

  my $self = bless {
    bin    => $args{bin}    || which("pygmentize") || "/usr/bin/pygmentize",
    lexer  => $args{lexer}  || "text",
    format => $args{format} || "html",
    options => $args{options} || "linenos=True",
  }, $class;

  return $self;
}

sub has_lexer {
  my ($self, $lexer) = @_;
  return first { $_ eq $lexer } @{$self->lexers};
}

sub lexers {
  my $self = shift;
  $self->{lexers} ||= $self->build_lexers;
}

sub build_lexers {
  my $self = shift;

  my($wtr, $rdr, $err);
  $err = gensym; #ugh

  my $pid = open3($wtr, $rdr, $err,  $self->{bin}, "-L", "lexers");
  close $wtr;
  waitpid($pid, 0);

  my @lexers;

  while (my $line = <$rdr>) {
    if ($line =~ /^* (.+):/) {
      push @lexers, split ", ", $1;
    }
  }

  return \@lexers;
}

sub colorize {
  my ($self, $text, %opts) = @_;

  my($wtr, $rdr, $err);
  $err = gensym; #ugh

  my $pid = open3($wtr, $rdr, $err, $self->command(%opts));
  print $wtr $text;
  close $wtr;
  waitpid($pid, 0);

  local $/;
  my $err = <$err>;
  my $out = <$rdr>;

  if ($err) {
    carp $err if $err;
    return $text;
  }
  $out =~ s{</pre></div>\Z}{</pre>\n</div>};
  return $out;
}

sub command {
  my ($self, %opts) = @_;

  if ($opts{lexer} and !$self->has_lexer($opts{lexer})) {
    $opts{lexer} = "text";
  }

  return (
    $self->{bin},
    '-l', $opts{lexer}   || $self->{lexer},
    '-f', $opts{format}  || $self->{format},
    '-O', $opts{options} || $self->{options},
  );
}

1;
