package Treex::Tool::SRLParser::LPInference;

use Moose;
use lib '/net/projects/tectomt_shared/external_libs/';
use LPSolve;

has 'empty_sign' => (
    is      => 'rw',
    isa     => 'Str',
    default => '_',
);

sub lpsolve_srl() {
    my ( $self, $probs_ref ) = @_; 
   
    # prune too small probabilities
    foreach my $key (keys %{$probs_ref}) {
        my ($predicate_id, $depword_id, $functor) = split / /, $key;

        # keep "NULL" even when has small probability
        next if $functor eq $self->empty_sign;

        # Che et al.: C2 condition: delete improbable labels
        # TODO: find optimal threshold (Che has 0.3)
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

    ### C1: Each predicate-depword pair should be labeled with one      ###
    ### and exactly one label                                           ###
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
    # pruned already at the beginning
    
    ### C3: Statistics show that some roles usually appear ###
    ### once for a predicate.                              ###
    # roles to appear once for predicate (TODO: only for Czech here)
    my %no_dup_roles = ('ACT', 'ADDR', 'CRIT', 'LOC', 'PAT', 'DIR3', 'COND');
    # find out predicates
    my %predicates;
    foreach my $var (@variables) {
        my ($predicate_id, $depword_id, $functor) = split / /, $var;
        $predicates{$predicate_id} = 1;
    }
    # make constraint for each predicate and each no dup role
    foreach my $predicate (keys %predicates) {
        foreach my $no_dup_role (keys %no_dup_roles) {
            for (my $i = 0; $i < $n_variables; $i++) {
                my ($predicate_id, $depword_id, $functor) = split / /, $variables[$i];
                $constraint->setitem($i+1, (($predicate_id eq $predicate) and ($no_dup_role eq $functor)) ? 1 : 0); 
            }
        }
        LPSolve::add_constraint($lp, $constraint, $LPSolve::LE, 1);
    }
   
    # turn off rowmode
    LPSolve::set_add_rowmode($lp, 0);

    # solve LP
    my $return_code = LPSolve::solve($lp);

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
