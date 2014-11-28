package Treex::Core::Loader;

use strict;
use warnings;

use Exporter 'import';
use File::Spec::Functions qw(catdir catfile splitdir);
use File::Basename 'fileparse';
use Treex::Core::Log;

our @EXPORT_OK = qw(class_to_path load_module search_module);

sub class_to_path { return join '.', join('/', split /::|'/, shift),'pm'; }

sub load_module {
  my ($module) = @_;

  # Check module name
  return 0 if !$module || $module !~ /^\w(?:[\w:']*\w)?$/;

  # Load
  return 1 if $module->can('new') || eval "require $module; 1";

  # Exists
  return 0 if $@ =~ /^Can't locate \Q@{[class_to_path $module]}\E in \@INC/;

  # Real error
  log_fatal $@;
  return;
}

sub search_module {
  my ($ns) = @_;

  my (@modules, %found);
  for my $directory (@INC) {
    next unless -d (my $path = catdir $directory, split(/::|'/, $ns));

    # List "*.pm" files in directory
    opendir(my $dir, $path);
    for my $file (grep { /\.pm$/ } readdir $dir) {
      next if -d catfile splitdir($path), $file;
      my $class = "${ns}::" . fileparse $file, qr/\.pm/;
      push @modules, $class unless $found{$class}++;
    }
  }

  return \@modules;
}

1;
__END__

=head1 NAME

Treex::Core::Loader - Loader

=head1 SYNOPSIS

    use Treex::Core::Loader;

=head1 DESCRIPTION

Stub documentation for Treex::Core::Loader,

Blah blah blah.

=head2 EXPORT

None by default.

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Michal Sedlak, E<lt>sedlakmichal@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 BUGS

None reported... yet.

=cut
