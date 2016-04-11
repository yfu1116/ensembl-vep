=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

 Questions may also be sent to the Ensembl help desk at
 <http://www.ensembl.org/Help/Contact>.

=cut

# EnsEMBL module for Bio::EnsEMBL::VEP::Runner
#
#

=head1 NAME

Bio::EnsEMBL::VEP::Runner - runner class for VEP

=cut


use strict;
use warnings;

package Bio::EnsEMBL::VEP::Runner;

use parent qw(Bio::EnsEMBL::VEP::BaseVEP);

use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::VEP::Config;
use Bio::EnsEMBL::VEP::AnnotationSourceAdaptor;

# has our own new method, does not use BaseVEP's
# since this is the class users will be instantiating
sub new {
  my $caller = shift;
  my $class = ref($caller) || $caller;
  
  # initialise self
  my $self = bless {}, $class;

  # get a config object
  $self->{_config} = Bio::EnsEMBL::VEP::Config->new(@_);

  return $self;
}

# dispatcher/runner for all initial setup from config
sub init {
  my $self = shift;

  return 1 if $self->{_initialized};

  # setup DB connection
  $self->setup_db_connection();

  # get all annotation sources
  my $annotation_sources = $self->get_all_AnnotationSources();

  return $self->{_initialized} = 1;
}

sub setup_db_connection {
  my $self = shift;

  return if $self->param('offline');

  # doing this inits the registry and DB connection
  my $reg = $self->registry();

  # check assembly
  if(my $csa = $self->get_adaptor('core', 'CoordSystem')) {
    my ($highest_cs) = @{$csa->fetch_all()};
    my $assembly = $highest_cs->version();

    my $config_assembly = $self->param('assembly');

    die(
      "ERROR: Assembly version specified by --assembly (".$config_assembly.
      ") and assembly version in coord_system table (".$assembly.") do not match\n".
      (
        $self->param('host') eq 'ensembldb.ensembl.org' ?
        "\nIf using human GRCh37 add \"--port 3337\"".
        " to use the GRCh37 database, or --offline to avoid database connection entirely\n" :
        ''
      )
    ) if $config_assembly && $config_assembly ne $assembly;

    # update to database version
    $self->param('assembly', $assembly);

    if(!$config_assembly) {
      die("ERROR: No assembly version specified, use --assembly [version] or check the coord_system table in your core database\n");
    }
  }

  # update species, e.g. if user has input "human" we get "homo_sapiens"
  $self->species($reg->get_alias($self->param('species')));

  return 1;
}

sub get_all_AnnotationSources {
  my $self = shift;

  if(!exists($self->{_annotation_sources})) {
    my $asa = Bio::EnsEMBL::VEP::AnnotationSourceAdaptor->new({config => $self->config});
    $self->{_annotation_sources} = $asa->get_all;
  }

  return $self->{_annotation_sources};
}

1;