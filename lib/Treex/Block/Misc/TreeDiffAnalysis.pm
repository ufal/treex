package Treex::Block::Misc::TreeDiffAnalysis;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


has gold_selector => ( isa => 'Treex::Type::Selector', is => 'ro', default => q{} );


my %POS_count;
my %POS_errors;


sub process_atree {
    my ( $self, $atree ) = @_;

    my $gold_atree = $atree->get_bundle->get_zone($self->language, $self->gold_selector)->get_atree;

    my @anodes = $atree->get_descendants({ordered=>1});
    my @gold_anodes = $gold_atree->get_descendants({ordered=>1});

    if (@anodes != @gold_anodes) {
        log_fatal "The two trees to compare must contain an identical number of tokens: "
            .scalar(@anodes)." vs ".scalar(@gold_anodes)." in bundle id = ".$atree->get_bundle->id;
    }

    foreach my $i (0..$#anodes) {
        my $POS = substr($anodes[$i]->tag,0,2);
        $POS_count{$POS}++;
        if ($anodes[$i]->get_parent->ord != $gold_anodes[$i]->get_parent->ord) {
            $POS_errors{$POS}++;
        }
    }
    return 1;
}

END {

    foreach my $POS (sort {$POS_count{$b}<=>$POS_count{$a}} keys %POS_count) {
        print join "\t",(
            $POS,
            $POS_count{$POS},
            $POS_errors{$POS}||0,
            sprintf("%.2f",($POS_errors{$POS}||0) / $POS_count{$POS})
        );
        print "\n";

    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Misc::TreeDiffAnalysis - prints error analysis when comparing an atree with the gold annotation

=head1 AUTHOR

Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
