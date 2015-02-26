package Treex::Block::W2A::PT::FixAfuns;
use Moose;
extends 'Treex::Core::Block';

# TODO: this block is needed for an unexpected error:
# the LX tagger tends to assign a clitic tag to "se" even is situations
# in which it serves as a subconj. However, when the tagger output is
# fixed in this respect, the parser does not give the "se" node the proper deprel
# (as with other correctly recognized se-if) which in turn leads to wrong afun.
# That is why the same condition for fixing "se" appears now twice 
# here and in FixTags.pm

sub process_anode {
    my ( $self, $anode ) = @_;
    if (lc($anode->form) eq 'se'){

        my $previous_anode = $anode->get_prev_node;
        if($previous_anode
            and $previous_anode->attr('conll/cpos') eq 'V') {
            $anode->set_afun('AuxC');
        }

    }  
    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::PT::Tokenize

=head1 DESCRIPTION

Uses LX-Suite tokenizer to split a sentence into a sequence of tokens.

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
