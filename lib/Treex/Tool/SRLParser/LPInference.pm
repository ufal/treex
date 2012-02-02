package Treex::Tool::SRLParser::LPInference;

use Moose;
use lib '/net/projects/tectomt_shared/external_libs/';
use LPSolve;

sub lpsolve_srl() {
    my ( $self, $probs_ref ) = @_; 
   
    # prune too small probabilities
    foreach my $key (keys %{$probs_ref}) {
        # TODO: Che et al. keep "NULL" even if it has small probability - try it out
        delete $probs_ref->{$key} if $probs_ref->{$key} < 0.1;
    }

    my @variables = keys %{$probs_ref};
    my $n_variables = @variables;

    # create lp    
    my $lp = LPSolve::make_lp(0, $n_variables);
    LPSolve::set_verbose($lp, $LPSolve::NEUTRAL);
    LPSolve::set_add_rowmode($lp, 1);

    # set objective function
    my $objective_function = LPSolve::DoubleArray->new($n_variables + 1);
    for (my $i = 0; $i < $n_variables; $i++) {
        $objective_function->setitem($i + 1, $probs_ref->{$variables[$i]});
    }
    LPSolve::set_obj_fn($lp, $objective_function);

    # set sense to "maximize"
    LPSolve::set_sense($lp, 1);

    # set all variables binary
    for (my $i = 0; $i < $n_variables; $i++) {
        LPSolve::set_binary($lp, $i, 1);
    }

    # set constraints
    my $constraint = LPSolve::DoubleArray->new($n_variables + 1);

    ### C1: Each predicate-depword pair should be labeled with one and exactly one label ###
    # find out word pairs
    my %word_pairs;
    foreach my $var (@variables) {
        my ($predicate_id, $depword_id, $functor) = split / /, $var;
        $word_pairs{$predicate_id." ".$depword_id} = 1;
    }
    # make constraint for each word pair
    foreach my $pair (keys %word_pairs) {
        for (my $i = 0; $i < $n_variables; $i++) {
            my ($predicate_id, $depword_id, $functor) = split / /, $variables[$i];
            $constraint->setitem($i+1, $pair eq $predicate_id." ".$depword_id ? 1 : 0);
        }
        LPSolve::add_constraint($lp, $constraint, $LPSolve::EQ, 1);
    }

    ### C2: Roles with a small probability should never be labeled ###
    ### (except for the virtual role "NULL")                       ###
   
    # turn off rowmode
    LPSolve::set_add_rowmode($lp, 0);

    # solve LP
    my $return_code = LPSolve::solve($lp);
    print STDERR "LP solve finished with code $return_code.\n";

    # get selected variables
    my $outcome_variables = LPSolve::DoubleArray->new($n_variables);
    LPSolve::get_variables($lp, $outcome_variables);

    # copy selected variables in Perl array
    my @return_variables;
    for (my $i = 0; $i < $n_variables; $i++) {
        push @return_variables, $variables[$i] if $outcome_variables->getitem($i);
    }

    # delete LP and return selected variables
    LPSolve::delete_lp($lp);
    return @return_variables;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::SRLParser::LPInference

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

Jana Straková <strakova@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
