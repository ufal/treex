package Treex::Service::MDP;

use strict;
use warnings;
use base 'Exporter';

our $VERSION = '0.01';

sub C_CLIENT { 'MDPC01' };
sub W_WORKER { 'MDPW01' };

sub W_READY { "\001" };
sub W_REQUEST { "\002" };
sub W_REPLY { "\003" };
sub W_HEARTBEAT { "\004" };
sub W_DISCONNECT { "\005" };

sub HEARTBEAT_TIMEOUT { 20 } # sec
sub HEARTBEAT_INTERVAL { 5 } # 3-5s is reasonable

our @EXPORT_OK = qw(HEARTBEAT_INTERVAL
                    HEARTBEAT_TIMEOUT
                    W_WORKER
                    W_READY
                    W_REQUEST
                    W_REPLY
                    W_HEARTBEAT
                    W_DISCONNECT
                    C_CLIENT);

our %EXPORT_TAGS = (
    heartbeat => [qw(HEARTBEAT_INTERVAL HEARTBEAT_TIMEOUT)],
    worker => [qw(W_WORKER W_READY W_REQUEST W_REPLY W_HEARTBEAT W_DISCONNECT)],
    client => [qw(C_CLIENT)]
);

$EXPORT_TAGS{all} = [ @EXPORT_OK ];

1;
__END__

=head1 NAME

Treex::Service::MDP - ZMQ Majordomo Protocol definitions

=head1 SYNOPSIS

   use Treex::Service::MDP;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Service::MDP,

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
