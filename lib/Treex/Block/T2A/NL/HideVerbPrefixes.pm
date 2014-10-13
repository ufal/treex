package Treex::Block::T2A::NL::HideVerbPrefixes;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;

    return if ( ($tnode->formeme // '') !~ /^v/ );
    
    my ( $prefix, $verb ) = ( ( $tnode->t_lemma || '' ) =~ /^([^_]+)_(.*)$/ );

    # only for verbal nodes with some particles
    return if ( !$prefix );
    my $anode = $tnode->get_lex_anode() or return;
        
    # remove prefix from the verbal node lemma and hide it in wild/verbal_prefix
    $anode->set_lemma($verb);
    $anode->wild->{verbal_prefix} = $prefix;

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::HideVerbPrefixes

=head1 DESCRIPTION

Verbal separable prefixes are hidden to simplify morphology generation.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
