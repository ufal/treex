package Treex::Block::A2T::LA::AddPersPron;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_tnode {
    my ( $self, $t_node ) = @_;

    # Add ACT/#PersPron nodes 
    if ($t_node->is_clause_head
        && !grep { ( ( $_->functor || "" ) eq "ACT" ) || ( ( $_->formeme || "" ) eq "n:1" ) } 
        $t_node->get_echildren( { or_topological => 1 } )
        )
    {                
        my $new_node = $t_node->create_child;
        $new_node->set_t_lemma('#PersPron');
        $new_node->set_functor('ACT');
        $new_node->set_formeme('drop');

        $new_node->set_nodetype('complex');
        $new_node->set_gram_sempos('n.pron.def.pers');
        $new_node->set_is_generated(1);
        $new_node->shift_before_node($t_node);

        #my @anode_tags = $self->_get_anode_tags($t_node);
        
        # new ADD
        my @anode_tags = map {$_->tag} $t_node->get_anodes();


        my ( $person, $gender, $number );
        my ( $aux_gender, $aux_number );

        
        if (any {/^3..(J|K|L|M|N|O|P|Q)...(4|7)/} @anode_tags && $t_node->t_lemma !~ /r$/){
            # at least one of the @anode_tags matches the regex
            # and the t_lemma does not end with 'r'
            #????? DON'T ADD A NEW NODE PersPron if t_lemma does not end with 'r'
            $person = "1";
        }
        
         elsif ( grep { ( $_ =~ /^3..(A|B|C|D|E|G|H)...(4|7)/ ) } @anode_tags ) { # include 'ego', 'nos'
            $person = "1";
        }
        
        elsif ( grep { $_ =~ /^3..(J|K|L|M|N|O|P|Q)...(5|8)/ } @anode_tags && $t_node->t_lemma !~ /r$/ ) { # include 'tu', 'vos'
             #???? DON'T ADD A NEW NODE PersPron if t_lemma does not end with 'r'
            $person = "2";
        }
         elsif ( grep { $_ =~ /^3..(A|B|C|D|E|G|H)...(5|8)/ } @anode_tags ) { # include 'tu', 'vos'
            $person = "2";
        }
        else {
            $person = "3";
        }

       # if ( grep { ( $_ =~ /^3..[789]...[ABCDEGH]/ ) || ( ( $_ =~ /^3..[789]...[JKLMNOP]/ ) && $t_node->t_lemma =~ /r$/ ) } @anode_tags ) {
        #    $number = 'pl';
        #}
        if (any {/^3..(J|K|L|M|N|O|P|Q)...(7|8|9)/} @anode_tags && $t_node->t_lemma !~ /r$/){
            # at least one of the @anode_tags matches the regex
            # and the t_lemma does not end with 'r'
            #????? DON'T ADD A NEW NODE PersPron if t_lemma does not end with 'r'
            $number = "pl";
        }
        elsif (any {/^3..(A|B|C|D|E|G|H)...(7|8|9)/} @anode_tags ){
            $number = "pl";
        }
       # elsif ( grep { ( $_ =~ /^3..[456]...[ABCDEGH]/ ) || ( ( $_ =~ /^3..[456]...[JKLMNOP]/ ) && $t_node->t_lemma =~ /r$/ ) } @anode_tags ) { 
        #    $number = 'sg';
        #}
         elsif ( grep { $_ =~ /^3..(J|K|L|M|N|O|P|Q)...(4|5|6)/ } @anode_tags && $t_node->t_lemma !~ /r$/ ) { # include 'tu', 'vos'
             #???? DON'T ADD A NEW NODE PersPron if t_lemma does not end with 'r'
            $number = "sg";
        }
         elsif ( grep { $_ =~ /^3..(A|B|C|D|E|G|H)...(4|5|6)/ } @anode_tags ) { # include 'tu', 'vos'
            $number = "sg";
        }
        

        $new_node->set_gram_person($person);
        $new_node->set_gram_gender($gender);
        $new_node->set_gram_number($number);
        $new_node->wild->{'aux_gram/number'} = $aux_number if (defined $aux_number);
        $new_node->wild->{'aux_gram/gender'} = $aux_gender if (defined $aux_gender);
    }
    return;
}

sub _get_anode_tags {
    my ($self, $t_node) = @_;
    return map { $_->tag } ( $t_node->get_lex_anode, $t_node->get_aux_anodes );
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::LA::AddPersPron

=head1 DESCRIPTION

Latin nodes with t_lemma #PersPron corresponding to unexpressed ('prodropped') subjects of finite clauses
are added.

=head1 AUTHORS

Christophe Onambélé <christophe.onambele@unicatt.it>

Berta González Saavedra <Berta.GonzalezSaavedra@unicatt.it>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by The CIRCSE Research Centre, Università Cattolica del Sacro Cuore (Milan, Italy)

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
