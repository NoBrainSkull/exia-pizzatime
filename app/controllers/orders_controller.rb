require 'json'

class OrdersController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_action :validate_token


  # Get the list of orders
  #
  # == Returns:
  # An array containing pizzas ans users'name.
  #
  def index
    result = []
    User.all.each do |u|
      user_orders = Order.live.placedBy(u)
      next if user_orders.blank?

      user_orders.each do |o|
        entry = {id: o.id}
        entry[:items] = o.order_items.map do |item|
          {pizzaId: item.pizza.id, baseId: item.base.id}
        end
        entry[:date] = o.created_at
        entry[:paid] = o.paid
        entry[:delivered] = o.is_delivered?
        entry[:price] = o.order_items.inject(0){|sum, i| sum + i.pizza.price}
        entry[:paymentDate] = o.payment_date
        result.append(entry)
      end
    end
    render_success(result)
  end

  # Discontinue an order (not deleted)
  #
  # == Returns:
  # An array containing pizzas ans users'name.
  #
  def destroy
    order = Order.find(params[:order_id])
    raise Exceptions::UnAuthorized if (order.user.email != session[:email] || order.discontinued)
    raise Exceptions::SalesAreClosed if o.flag == 0
    render_success(order.update!(flag: -1))
  end


  # Create a new order
  def create
    u = User.current(request.headers['token']);
    raise Exceptions::BadRequest if u.nil?
    order = Order.create!(user_id: u.id, ordered_for: getCurrentEndDate())
    order.order_items = items_parameters(order)
    order.save!
    render_success(order)
  end

  # Display a summary of the orders sorted by pizzas
  #
  # == Returns:
  # An array containing a name of a pizza, and the quantity of each one.
  #
  def summary
    render_success(Order.order_summary)
  end

  # Print the total price for all the current orders
  #
  # == Returns:
  # The price.
  #
  def total
    render_success(Order.total_price)
  end

  # Allow people to place orders
  #
  def open_sales
    Order.open_sales(params[:open])
    render_success
  end

  # List unpaid orders
  #
  def unpaid_orders
    render_success(Order.unpaid)
  end

  # price and delivered status
  #
  def update
    order = Order.find_by(id:params[:order_id])
    raise Exceptions::BadRequest if order.nil?
    OrderItem.where(order_id: order.id).delete_all
    order_items = items_parameters(order)
    order.save!
    order.deliver if update_parameters[:delivered]
    order.lock if update_parameters[:lock]
    order.pay if update_parameters[:paid]
    render_success(order)
  end

  def cancel
    order = Order.find_by(id: params[:order_id])
    raise Exceptions::BadRequest if order.nil?
    render_success(order.cancel)
  end


  private

  def order_parameters
    params.require(:user)
  end

  def update_parameters
    params.permit(:paid, :delivered, :lock, :base, :id)
  end

  def items_parameters(order)
    order_items = []
    params[:items].each do |item|
      o = OrderItem.create!(order_id: order.id, pizza_id: item[:pizzaId], base_id: item[:baseId])
      order_items.append(o)
    end
    return order_items
  end

end
