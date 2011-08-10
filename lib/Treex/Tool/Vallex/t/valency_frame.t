#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Tool::Vallex::ValencyFrame;

{
    my $frame = Treex::Tool::Vallex::ValencyFrame->new( { id => 'v-w3f1', lexicon => 'vallex.xml', language => 'cs' } );
    print $frame->to_string . "\n";

    $frame = Treex::Tool::Vallex::ValencyFrame->new( { id => 'v-w3351f3', lexicon => 'vallex.xml', language => 'cs' } );
    print $frame->to_string . "\n";

    $frame = Treex::Tool::Vallex::ValencyFrame->new( { id => 'v-w3352f1', lexicon => 'vallex.xml', language => 'cs' } );
    print $frame->to_string . "\n";

    $frame = Treex::Tool::Vallex::ValencyFrame->new( { ord => '1000', lexicon => 'vallex.xml', language => 'cs' } );
    print $frame->to_string . "\n";

}

__END__

=encoding utf-8

Valency Lexicon test -- load and print several random valency frames from the PDT-Vallex Czech valency lexicon.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
