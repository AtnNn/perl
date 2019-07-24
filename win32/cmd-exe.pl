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
    ( (\\\\) *)
    ( ( \\" )
    | ( "
      ( $wordchar | [ ] | \\\\ | \\" )+
    " ) )
  /nx;
  my @tokens;
  while ($c =~ /
    ( (?<and> \&\& )
    | (?<word> ( $wordchar | \^. | $quoted )+ )
    | (?<nope> . )
    )
    [ \t\r\n]*
  /gxns) {
    # print STDERR "\nword: " . Dumper($+);
    if (defined $+{nope}) { die("cannot parse: ".$c) }
    if (defined $+{and}) { push @tokens, $+{and} }
    if (defined $+{word}) {
      my $word = $+{word};
      $word =~ s/ \^ (.) /$1/xg;
      $word =~ s/
        ((\\\\)*) ( \\? " )
	/ ($1 =~ s|\\\\|\\|rg) .
          ($3 eq "\"" ? "" : "\"") /xge;
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
  my ($op) = indexof(qr/^ \&\& $/x, @cmd);
  # print STDERR "\nop: ".Dumper($op);
  if (defined $op) {
    my $ret = evalcmd(@cmd[0 .. ($op - 1)]);
    if ($ret != 0) { return $ret }
    return evalcmd(@cmd[($op + 1) .. $#_])
  }
  given ($cmd[0]) {
    when (/^for$/i) { return eval_for(@cmd[1 .. $#_]) }
    when (/^set$/i) { return eval_set(@cmd[1 .. $#_]) }
    when (/^if$/i) { return eval_if(@cmd[1 .. $#_]) }
    when (/^copy$/i) { return eval_copy(@cmd[1 .. $#_]) }
    default {
      # print STDERR "system: ".join(" ",@cmd)."\n";
      return system(@cmd)
    }
  }
}

sub eval_copy {
  # die Dumper(@_);
  return evalcmd("cp", @_)
}

sub eval_if {
  my @args = @_;
  my $invert = 0;
  my $condition;
  if ($args[0] =~ /^not$/i) {
    shift @args;
    $invert = 1;
  }
  if ($args[0] =~ /^exist$/i) {
    $condition = -e $args[1];
    shift @args; shift @args;
  } else {
    die "eval_if error: @args";
  }
  if ($condition xor $invert) {
    return evalcmd(@args)
  }
}

sub indexof {
  # print STDERR ("\nindexof: ".Dumper(@_));
  my ($re, @list) = @_;
  my @res = grep { $list[$_] =~ m/$re/ } (0 .. $#list);
  # print STDERR ("\nindexes: ".Dumper(@res));
  return @res
}

# print STDERR "cmd-exe `".join(" ", @ARGV)."'\n";

given ($ARGV[0]) {
  when ("-c") { cmd($ARGV[1]); }
  default { die(join(" ", @ARGV)); }
}
