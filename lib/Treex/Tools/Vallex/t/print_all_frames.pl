#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Tools::Vallex::ValencyFrame;


my $i = 1;

while ( $i < 14983 ){
    my $frame = Treex::Tools::Vallex::ValencyFrame->new( {ord => $i++, lexicon => 'vallex.xml', language => 'cs'} );
    
    print $frame->to_string . "\n";
}

__END__

=encoding utf-8

This lists all the valency frames form the PDT-Vallex Czech valency lexicon.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
