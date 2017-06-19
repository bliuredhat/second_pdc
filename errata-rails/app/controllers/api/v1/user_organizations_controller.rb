class Api::V1::UserOrganizationsController < ApplicationController
  respond_to :json

  before_filter :admin_restricted

  def search
    respond_to do |format|
      list = []
      if params[:name].present?
        name = params[:name]
        list = UserOrganization.\
          includes(:users).\
          select('id, name, manager_id').\
          where('name like ?', "%#{name}%").\
          map{|org| {:id => org.id, :name => org.name, :manager => org.manager.realname}}
      end
      format.json { render :json => list.to_json}
    end
  end
end