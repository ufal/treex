package Treex::Block::W2A::PT::FixTags;
use Moose;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
  
    if (lc($anode->form) eq 'se'){

        my $previous_anode = $anode->get_prev_node;
        if($previous_anode and $previous_anode->attr('conll/cpos') eq 'V') {
            $anode->set_attr('conll/pos', 'CJ' );
            $anode->set_attr('conll/cpos', 'CJ');
            $anode->set_attr('conll/feat', '_');
        }
    }  
    return 1;
}

1;
    
__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::PT::FixTags

=head1 DESCRIPTION

Correct wrongly annotated 'se' conjunctions (in source they appear as clitics)

=head1 AUTHORS

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.



