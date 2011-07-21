#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Tool::Vallex::ValencyFrame;


my $i = 1;
my %forms;

while ( $i < 14983 ){
    my $frame = Treex::Tool::Vallex::ValencyFrame->new( {ord => $i++, lexicon => 'vallex.xml', language => 'cs'} );
    
    foreach my $element (@{ $frame->elements }){
        
        foreach my $form (@{ $element->forms_list }){
            if (!$forms{$form}){
                $forms{$form} = [];
            }
            push @{ $forms{$form} }, $frame->lemma . '-' . $frame->POS . ':' . $element->functor;
        }
    }
    if ( $i % 100 == 0 ){
        print STDERR $i . ' ';
    }
}
print STDERR "Loading done.\n";
   
foreach my $form ( keys %forms ){
    print $form . ': ' . join(' ', @{ $forms{$form} }) . "\n"; 
}

__END__

=encoding utf-8

This prints all the formemes that occur within the PDT-Vallex Czech valency lexicon, plus the corresponding
words and functors that make use of these formemes.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
