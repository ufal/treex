package Treex::Block::W2A::EN::FixTagsImperatives;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

Readonly my $TAGS_FILE => 'data/models/morpho_analysis/en/forms_with_more_tags.tsv';

# $CAN_BE{$tag}{$form} == 1 means that $form can have tag $tag
# Only forms with more possible tags are stored in this hash.
my %CAN_BE;

sub process_atree {
    my ( $self, $aroot ) = @_;
    my @anodes = $aroot->get_descendants({ordered=>1});
    for my $i (0..$#anodes){
        my $anode = $anodes[$i];
        if ($anode->form =~ /^((right-)?click|check|drag|take|log|press|turn|visit)$/i){
        
            # Imperative cannot be preceded by a determiner, or determiner+adjective,
            # in such cases, the original tag (NN) was correct.
            next if $i > 0 && $anodes[$i-1]->tag eq 'DT';
            next if $i > 1 && $anodes[$i-2]->tag eq 'DT' && $anodes[$i-1]->tag eq 'JJ'; # &&!$anodes[$i-1]->wild->{matched_item}; 
            $anode->wild->{orig_tag} = $anode->tag;
            $anode->set_tag('VB'); 
        }
    }
}

1;

__END__

# What follows is an attempt at more general detection of imperatives.
# However, the above list of verbs seems to work better on QTLeap Batch 1,
# so I left the solution below.

sub process_start {
    my $self = shift;
    my ($file_path) = $self->require_files_from_share($TAGS_FILE);
    open my $IN, '<:encoding(utf8)', $file_path or log_fatal $!;
    while (<$IN>) {
        chomp;
        my ( $form, @tags ) = split /\t/, $_;
        foreach my $tag (@tags) {
            $CAN_BE{$tag}{$form} = 1;
        }
    }
    close $IN;
    return;
}

sub NEWprocess_atree {
    my ( $self, $aroot ) = @_;
    my @clauses = $self->guess_clauses($aroot);
    foreach my $clause (@clauses){
        my $first_word = $clause->[0];
        
        # Check if the first word is a singular noun,
        next if $first_word->tag !~ /^NNP?$/;
        
        #  but could be also a base-form verb (imperative).
        next if !$CAN_BE{VB}{lc $first_word->form};
        
        # Check if there are no other possible verbs in the clause.
        next if any {$_->tag =~ /^(V|MD)/} @$clause;
        
        $first_word->wild->{orig_tag} = $first_word->tag;
        $first_word->set_tag('VB');
    }
    return;
}


sub guess_clauses {
    my ( $self, $aroot ) = @_;
    my (@clauses, @current_clause);
    foreach my $anode ($aroot->get_descendants({ordered=>1})){
        push @current_clause, $anode;
        if ($anode->form =~ /^([,;]|and|or)$/i){
            push @clauses, [@current_clause];
            @current_clause = ();
        }
    }
    push @clauses, \@current_clause if @current_clause;
    return @clauses;
}



=encoding utf-8

=head1 NAME 

Treex::Block::W2A::EN::FixTagsImperatives - change some NN to VB

=head1 DESCRIPTION

Taggers trained on PennTB are not good at detecting imperative verbs, which should be tagged as "VB".
This block changes some NN and NNP tags to VB, thus increasing the chance of detecting imperatives.
Using it for texts without imperatives may be harmful.

See the source code for the details.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.