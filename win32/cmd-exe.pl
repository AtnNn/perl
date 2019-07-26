#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;
no warnings 'experimental';

use Data::Dumper;
use POSIX qw(dup dup2);

sub cmd {
  my ($c) = @_;
  # print STDERR "\nprocessed cmd: ".Dumper($c);
  my $unescaped = qr/ (?<! \^ ) /nx;
  my $wordchar = qr/( [a-zA-Z0-9\-_%=.\/#*,] | \\ (?! \\* " ) | \^. )/nx;
  my $quoted = qr/
    ( (\\\\) *)
    ( ( \\" )
    | ( "
      ( $wordchar | [ ] | \\\\ | \\" )+
    " ) )
  /nx;
  my $operator = qr/
    $unescaped
    ( \&\&
    | [0-9]* ( > >? )
    | \( | \)
    # | \\ \n
    ) /nx;
  my $token = qr/
    ( (?<op> $operator )
    | (?<word> ( $wordchar | \^. | $quoted )+ )
    )
  /nxs;
  my $white = qr/ ( [ \t\r\n] | \\ \n ) * /nx;
  my @tokens;
  while ($c =~ /
    ( $token
    | (?<nope> .{1,20} )
    )
    $white
  /gxns) {
    # print STDERR "\nword: " . Dumper($+);
    if (defined $+{nope}) { die("cannot parse (at '$+{nope}'):".$c) }
    if (defined $+{op}) { push @tokens, $+{op} }
    if (defined $+{word}) {
      my $word = $+{word};
      $word =~ s/
        ((\\\\)*) ( \\? " )
	/ ($1 =~ s|\\\\|\\|rg) .
          ($3 eq "\"" ? "" : "\"") /xge;
      push @tokens, $word;
    }
  }
  # print STDERR "\ntokens: " . Dumper(@tokens);
  my $code = evalcmds(@tokens);
  if ($code == 0) {
    exit(0)
  } else {
    die("faled with code $code: " . join(" ", @tokens));
  }
}

sub popcmd {
  my ($cmds) = @_;
  my @ret;
  my $inparen = 0;
  while ($#$cmds != -1) {
    my $next = $cmds->[0];
    if (!$inparen && $next =~ / ^( \&\& | \\ \n )$ /nx) {
      return @ret;
    }
    shift @$cmds;
    push @ret, $next;
    if ($next eq "(") {
      $inparen++;
    }
    if ($next eq ")") {
      if (!$inparen) {
        die "unmatched ')'";
      }
      $inparen--;
    }
  }
  return @ret;
}

sub evalcmds {
  print STDERR "\nevalcmds: ".Dumper(\@_);
  my @cmds = @_;

  my @cmd = popcmd(\@cmds);
  print STDERR "\npopped: ".Dumper(\@cmd);
  print STDERR "\nrest: ".Dumper(\@cmds);

  if ($#cmd == -1) {
    die "empty command!";
  }

  my $ret = 1;

  if ($#cmd >= 1 && $cmd[$#cmd-1] =~ / (?<! \^) (?<fd> [0-9]*) (?<mode> >>?) $ /xn) {
    my $outfile = $cmd[$#cmd];
    $outfile = "/dev/null" if $outfile =~ /^NUL$/i;
    my $infd = $+{"fd"};
    $infd = STDOUT->fileno if $infd eq "";
    my $savedfd = [$infd, dup($infd)];
    open(my $out, $+{mode}, $outfile) or die;
    dup2($out->fileno, $infd) or die;
    $ret = evalcmds(@cmd[0 .. ($#cmd - 2)]);
    dup2($savedfd->[1], $savedfd->[0]);
  } elsif ($cmd[0] eq "(") {
    if ($cmd[$#cmd] ne ")") {
      die "missing ')' in: @cmd";
    }
    shift @cmd;
    pop @cmd;
    $ret = evalcmds(@cmd);
  } else {
    for (@cmd) { s/ \^ (.) /$1/xg }
    $cmd[0] =~ s/ \. $ //x;
    given ($cmd[0]) {
      when (/^for$/i) { $ret = eval_for(@cmd[1 .. $#_]) }
      when (/^set$/i) { $ret = eval_set(@cmd[1 .. $#_]) }
      when (/^if$/i) { $ret = eval_if(@cmd[1 .. $#_]) }
      when (/^copy$/i) { $ret = eval_copy(@cmd[1 .. $#_]) }
      when (/^rem$/i) { $ret = 0 }
      default {
        print STDERR "system: ".join(" ",@cmd)."\n";
        $ret = system(@cmd)
      }
    }
  }

  if ($#cmds == -1) {
    return $ret;
  } elsif ($cmds[0] eq "&&") {
    if ($ret != 0) { return $ret }
    return evalcmds(@cmds[1 .. $#cmds])
  } elsif ($cmds[0] eq "\\\n") {
    return evalcmds(@cmds[1 .. $#cmds])
  } else {
    die "unknown tail: @cmds";
  } 
}

sub eval_copy {
  # die Dumper(@_);
  return evalcmds("cp", @_)
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
    return evalcmds(@args)
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
