#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;
no warnings 'experimental';

use Data::Dumper;

sub cmd {
  my ($c) = @_;
  $c =~ s/ \\ \n / /gx;
  # print STDERR "\nprocessed cmd: ".Dumper($c);
  my $wordchar = qr/( [a-zA-Z0-9\-_%=.\/#] | \\ (?! \\* " ) )/nx;
  my $quoted = qr/
    ( (\\\\) +)
    ( ( \\" )
    | ( "
      ( $wordchar | [ ] | \\\\ | \\" )+
    " ) )
  /nx;
  my @tokens;
  while ($c =~ /
    ( (?<and> && )
    | (?<word> ( $wordchar | \^. | $quoted )+ )
    | (?<nope> . )
    )
    [ \t\r\n]*
  /gxns) {
    # print STDERR "\nword: " . Dumper($+);
    if (defined $+{nope}) { die(join(" ", @_)) }
    if (defined $+{and}) { push @tokens, $+{and} }
    if (defined $+{word}) {
      my $word = $+{word};
      $word =~ s/ \^ (.) /$1/xg;
      $word =~ s/
        ((\\\\)*) ( \\? " )
	/ ($1 =~ s|\\\\|\\|rg) .
          ($3 == "\"" ? "" : "\"") /xge;
      push @tokens, $word;
    }
  }
  # print STDERR "\ntokens: " . Dumper(@tokens);
  my $code = evalcmd(@tokens);
  if ($code == 0) {
    exit(0)
  } else {
    die("faled with code $code: " . join(" ", @tokens));
  }
}

sub evalcmd {
  # print STDERR "\nevalcmd: ".Dumper(@_);
  my @cmd = @_;
  my $op = indexof(qr/^&&$/, @cmd);
  if (!defined $op) {
    my $ret = evalcmd(@cmd[0 .. $op]);
    if ($ret != 0) { return $ret }
    return evalcmd(@cmd[($op+1) .. $#_])
  }
  given ($cmd[0]) {
    when (/^for$/i) { return eval_for(@cmd[1 .. $#_]) }
    when (/^set$/i) { return eval_set(@cmd[1 .. $#_]) }
    default { return system(@cmd) }
  }
}

sub indexof {
  # print STDERR ("\nindexof: ".Dumper(@_));
  my $re = shift @_;
  grep { $_[$_] =~ $re } 0..$#@;
}

print STDERR "cmd-exe ".join(" ", @ARGV)."\n";

given ($ARGV[0]) {
  when ("-c") { cmd($ARGV[1]); }
  default { die(join(" ", @ARGV)); }
}
