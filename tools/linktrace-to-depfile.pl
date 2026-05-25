#!/usr/bin/perl -w

use strict;
use Cwd ();

my %deps;

sub compat_abs_path {
   my $path = shift;
   my $abspath;
   my $cwd;

   if (defined &Cwd::abs_path) {
      $abspath = Cwd::abs_path($path);
      return $abspath if (defined $abspath);
   }

   return $path if ($path =~ m|^/|);

   if (defined &Cwd::getcwd) {
      $cwd = Cwd::getcwd();
   } elsif (defined &Cwd::cwd) {
      $cwd = Cwd::cwd();
   } else {
      chomp($cwd = `pwd`);
   }

   return "$cwd/$path";
}

my $line;

while (defined($line = <>)) {
   chomp $line;
   $line =~ s/[()]/ /g;
   my @words = split(/\s+/, $line);
   my $word;

   foreach $word (@words) {
      $deps{compat_abs_path($word)} = 1 if ($word =~ /\.a$/);
   }
}

my @deps = keys %deps;

print join("\t\\\n\t", @deps), "\n";
