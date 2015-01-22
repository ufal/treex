package Treex::Block::T2A::ES::AddSentFinalPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddSentFinalPunct';

has '+open_punct' => ( default => '[‚„\']' );

has '+close_punct' => ( default => '[‘“\']' );

override 'postprocess' => sub {
    my ( $self, $a_punct ) = @_;

    if ($a_punct->form eq '?' || $a_punct->form eq '!'){

	my $punct_mark = ($a_punct->form eq '!') ? '¡' : '¿';

	my $aroot = $a_punct->get_parent();;
	my $first_node = $aroot->get_root()->get_descendants( { first_only => 1 } );

	my $punct = $aroot->create_child(
	    {   'form'          => $punct_mark,
		'lemma'         => $punct_mark,
		'afun'          => 'AuxK',
		'morphcat/pos'  => 'Z',
		'clause_number' => 0,
	    }
	);
	$punct->iset->set_pos('punc');

        $punct->shift_before_node($first_node);
    }

    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::ES::AddSentFinalPunct

=head1 DESCRIPTION

Add a-nodes corresponding to sentence-final punctuation mark.


=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
