package Treex::Tool::Depfix::CS::TagHandler;
use Moose;
use Treex::Core::Common;
use utf8;

my %tag_cats = (
    'pos' => 0,
    
    subpos => 1,
    'sub' => 1,
    
    gender => 2,
    gen => 2,
    
    number => 3,
    num => 3,
    
    case => 4,
    cas => 4,
    
    possgender => 5,
    posgen => 5,
    pgen => 5,
    
    possnumber => 6,
    possnum => 6,
    pnum => 6,
    
    person => 7,
    pers => 7,
    per => 7,
    
    tense => 8,
    ten => 8,
    
    grade => 9,
    gra => 9,
    
    negation => 10,
    neg => 10,
    
    voice => 11,
    voi => 11,
    
    reserve1 => 12,
    reserve2 => 13,

    variant => 14,
    var => 14,
);

sub set_tag_cat {
    my ($tag, $cat, $value) = @_;

    if (defined $tag_cats{$cat}) {
        $cat = $tag_cats{$cat};
    }

    substr $tag, $cat, 1, $value;

    return $tag;
}

sub set_node_tag_cat {
    my ($node, $cat, $value) = @_;

    my $new_tag = set_tag_cat($node->tag, $cat, $value);
    $node->set_tag($new_tag);

    return $new_tag;
}

sub get_tag_cat {
    my ($tag, $cat) = @_;

    if (defined $tag_cats{$cat}) {
        $cat = $tag_cats{$cat};
    }

    my $value = substr $tag, $cat, 1;

    return $value;
}

sub get_node_tag_cat {
    my ($node, $cat) = @_;

    return get_tag_cat($node->tag, $cat);
}

sub get_empty_tag {
    return 'X@-------------';
}


1;

=head1 NAME 

Treex::Tool::Depfix::CS::TagHandler

=head1 DESCRIPTION

 my $number1 = get_tag_cat($tag, 'number');
 my $number2 = get_tag_cat($tag, 'num');
 my $number3 = get_tag_cat($tag, 3);
;
 my $new_tag1 = set_tag_cat($tag, 'gender', 'F');
 my $new_tag2 = set_tag_cat($tag, 'gen', 'F');
 my $new_tag3 = set_tag_cat($tag, 2, 'F');
;
=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

